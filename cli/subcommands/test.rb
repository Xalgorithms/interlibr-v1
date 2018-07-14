require 'active_support/core_ext/hash'
require 'faker'
require 'multi_json'
require 'thor'
require 'thread'
require 'timeout'

require_relative '../clients/events'
require_relative '../clients/query'
require_relative '../clients/revisions'
require_relative '../clients/schedule'
require_relative '../support/display'
require_relative '../support/cassandra'
require_relative '../support/kafka'
require_relative '../support/mongo'

module Subcommands
  class Test < Thor
    no_commands do
      def make_inserts(o, tn)
        o.fetch(tn, []).map do |d|
          ks = d.keys
          vs = ks.map { |k| "'#{d[k]}'" }
          "INSERT INTO #{tn} (#{ks.join(',')}) VALUES (#{vs.join(',')})"
        end
      end

      def populate_mongo(o)
        Support::Display::info('initializing mongo data')
        cl = Support::Mongo.new('mongodb://127.0.0.1:27017/xadf')
        o.keys.each do |collection|
          o.fetch(collection, []).each do |doc|
            cl.reset(collection, doc)
          end
        end
      end

      def populate_cassandra(o)
        Support::Display.info('initializing cassandra data')
        cl = Support::Cassandra.new('localhost')
        cl.truncate_tables(o.keys.map { |n| "xadf.#{n}" })
        inserts = o.keys.inject([]) do |a, tn|
          a + o.fetch(tn, []).map do |r|
            ks = r.keys
            vs = ks.map { |k| "'#{r[k]}'" }
            "INSERT INTO xadf.#{tn} (#{ks.join(',')}) VALUES (#{vs.join(',')})"
          end
        end

        Support::Display.info('inserting test data')
        cl.execute_batch(inserts)
      end

      def produce_and_consume(topics, msgs)
        k = Support::Kafka.new('localhost:9092')
        msgs.each do |m|
          k.send_single_message(topics['in'], m['in'])
          vals = k.receive_messages(topics['out']).sort

          if m['expect'] == nil
            actual = vals
            expect = m['out'].sort
          else
            ex = m['expect']
            collection = ex['collection']
            expect = ex['data']
            actual = get_entity_by_id(vals.first, collection)
          end

          if actual != expect
            Support::Display.error_strong("expected #{actual} to equal #{expect}")
          else
            Support::Display.info_strong("matched (#{actual} == #{expect})")
          end
        end
      end

      def get_entity_by_id(id, collection)
        cl = Support::Mongo.new('mongodb://127.0.0.1:27017/xadf')
        doc = cl.find_one_by_public_id(collection, id)
        Support::Display.warn("entity not found (id=#{id}; collection=#{collection})")
        doc ? doc.except('_id', 'public_id') : nil
      end
    end

    desc 'compute <path> [kafka_url]', 'Runs a test of a compute queue'
    def compute(path, kafka_url)
      Support::Display.info("running compute test (test=#{path})")
      o = MultiJson.decode(IO.read(path))

      populate_cassandra(o.fetch('cassandra', {}))
      populate_mongo(o.fetch('mongo', {}))
      topics = o.fetch('topics', nil)
      if topics
        Support::Display.info('sending messages')
        produce_and_consume(topics, o.fetch('messages', []))
      else
        Support::Display.error('no topics were defined')
      end
    end

    class Barrier
      def initialize
        @mutex = Mutex.new
        @cond = ConditionVariable.new
      end

      def signal
        @mutex.synchronize {
          @cond.signal
        }
      end

      def wait
        @mutex.synchronize {
          @cond.wait(@mutex)
        }
      end
    end
    
    desc 'exec <path> [schedule_url] [revisions_url] [events_url]', 'Runs a simple execute loop, uploading unpackaged rules and tables to revisions directly'
    def exec(path, schedule_url=nil, revisions_url=nil, events_url)
      cl = Clients::Revisions.new(revisions_url || 'http://localhost:9292')
      package_name = Faker::Dune.planet.downcase.gsub(' ', '_')
      
      rules = Dir.glob(File.join(path, '*.rule')).inject({}) do |o, fn|
        Support::Display.give("sending rule (#{fn})")
        name = File.basename(fn, '.rule')
        payload = {
          meta: { version: "99.99.99", package: package_name, name: name }, 
          content: IO.read(fn),
        }
        id = cl.send_rule(payload)
        Support::Display.got_ok("#{id}")
        id ? o.merge(name => id) : o
      end
      
      Dir.glob(File.join(path, 'tables/**/*.json')).each do |fn|
        Support::Display.give("sending table (#{fn})")
        m = fn.match(/.*\/tables\/(\w+)\/([0-9]+\.[0-9]+\.[0-9]+)\/(\w+)\.json/)
        (pkg, ver, n) = m[1..3]
        payload = {
          meta: { version: ver, package: pkg, name: n },
          content: IO.read(fn),
        }
        id = cl.send_table(payload)
        Support::Display.got_ok("#{id}")
      end
      
      scl = Clients::Schedule.new(schedule_url || 'http://localhost:9000')
      ecl = Clients::Events.new(events_url || 'http://localhost:4200')

      ready = Barrier.new
      reqs_q = Queue.new
      req_ids_q = Queue.new

      reqs = {}
      Support::Display.info_strong("starting events listener")
      thr = Thread.new do
        req_ids = Set.new
        q_req_ids = Set.new
        ecl.subscribe(['audit'], {
                        service: {
                          registered: lambda do |o|
                            Support::Display.info("event listener is ready")
                            ready.signal
                            false
                          end
                        },
                        audit: {
                          notified: lambda do |o|
                            if ('execution' == o['context']['task'] && 'end' == o['context']['action'])
                              req_id = o['args']['request_id']
                              req_ids << req_id
                              req_ids_q << req_id
                            end

                            while !reqs_q.empty?
                              q_req_ids << reqs_q.pop
                            end

                            q_req_ids.any? && q_req_ids.subset?(req_ids)
                          end
                        }
                      })
      end
      
      Support::Display.info_strong("waiting for listener to be ready")
      ready.wait

      Support::Display.info("sending requests")
      reqs = rules.inject({}) do |o, (name, id)|
        Support::Display.info("loading expectations (name=#{name})")
        expected = MultiJson.decode(IO.read(File.join(path, "#{name}.expected.json")))
        
        Support::Display.give("scheduling rule test (name=#{name}; id=#{id})")
        ctx_fn = File.join(path, "#{name}.context.json")
        ctx = File.exist?(ctx_fn) ? JSON.parse(IO.read(ctx_fn)) : {}
        req_id = scl.execute_adhoc(id, ctx)
        Support::Display.got_ok("scheduled rule test (name=#{name}; id=#{id}; req_id=#{req_id})")
        
        o.merge(req_id => { name: name, expected: expected })
      end

      reqs.keys.each { |id| reqs_q << id }
      
      Support::Display.info_strong("waiting for events")
      if !thr.join(10)
        Support::Display.warn("all events probably arrived early, synchronizing with events thread")
        req_ids = Set.new
        while !req_ids_q.empty?
          req_ids << req_ids_q.pop
        end
        Support::Display.warn("mismatched request sizes (reqs=#{reqs.keys.size}; req_ids=#{req_ids.size})") if reqs.keys.size != req_ids.size
      end

      qcl = Clients::Query.new('http://localhost:8000')
      Support::Display.info("checking expectations")
      reqs.each do |req_id, vals|
        step = qcl.last_step_by_request(req_id)
        if step
          ac_tables = step.fetch('context', {}).fetch('tables', {})
          ex_tables = vals[:expected].fetch('tables', [])
          ex_tables.each do |section, ex_section_tables|
            ac_section_tables = ac_tables.fetch(section, {})
            ex_section_tables.each do |name, ex_tbl|
              ac_tbl = ac_section_tables.fetch(name, nil)
              if !ac_tbl
                Support::Display.error("expected table to exist, but not found in results (test=#{vals[:name]}; section=#{section}; name=#{name}; req_id=#{req_id})")
                puts JSON.pretty_generate(step)
              elsif ac_tbl != ex_tbl
                Support::Display.error("expected tables to match (test=#{vals[:name]}; section=#{section}; name=#{name}; req_id=#{req_id})")
              else
                Support::Display.info_strong("tables matched (test=#{vals[:name]}; section=#{section}; name=#{name}; req_id=#{req_id})")
              end
            end
          end
        else
          Support::Display.error("failed to find last step (test=#{vals[:name]}; req_id=#{req_id})")
        end
      end
    end

    desc 'exec_ref <rule_ref> <ctx_path> [schedule_url]', 'schedules a rule execution by reference'
    def exec_ref(rule_ref, ctx_path, schedule_url=nil)
      puts "> scheduling rule execution (ref=#{rule_ref}; ctx=#{ctx_path})"
      scl = Clients::Schedule.new(schedule_url || 'http://localhost:9000')
      ctx = File.exist?(ctx_path) ? JSON.parse(IO.read(ctx_path)) : {}
      req_id = scl.execute(rule_ref, ctx)
      puts "> scheduled execution (req_id=#{req_id})"
    end
  end
end
