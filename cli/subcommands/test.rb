require 'active_support/core_ext/hash'
require 'faker'
require 'multi_json'
require 'terminal-table'
require 'thor'
require 'thread'
require 'timeout'
require 'xa/rules/parse/content'

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
    include XA::Rules::Parse::Content
    # no_commands do
    #   def make_inserts(o, tn)
    #     o.fetch(tn, []).map do |d|
    #       ks = d.keys
    #       vs = ks.map { |k| "'#{d[k]}'" }
    #       "INSERT INTO #{tn} (#{ks.join(',')}) VALUES (#{vs.join(',')})"
    #     end
    #   end

    #   def populate_mongo(o)
    #     Support::Display::info('initializing mongo data')
    #     cl = Support::Mongo.new('mongodb://127.0.0.1:27017/xadf')
    #     o.keys.each do |collection|
    #       o.fetch(collection, []).each do |doc|
    #         cl.reset(collection, doc)
    #       end
    #     end
    #   end

    #   def populate_cassandra(o)
    #     Support::Display.info('initializing cassandra data')
    #     cl = Support::Cassandra.new('localhost')
    #     cl.truncate_tables(o.keys.map { |n| "xadf.#{n}" })
    #     inserts = o.keys.inject([]) do |a, tn|
    #       a + o.fetch(tn, []).map do |r|
    #         ks = r.keys
    #         vs = ks.map { |k| "'#{r[k]}'" }
    #         "INSERT INTO xadf.#{tn} (#{ks.join(',')}) VALUES (#{vs.join(',')})"
    #       end
    #     end

    #     Support::Display.info('inserting test data')
    #     cl.execute_batch(inserts)
    #   end

    #   def produce_and_consume(topics, msgs)
    #     k = Support::Kafka.new('localhost:9092')
    #     msgs.each do |m|
    #       k.send_single_message(topics['in'], m['in'])
    #       vals = k.receive_messages(topics['out']).sort

    #       if m['expect'] == nil
    #         actual = vals
    #         expect = m['out'].sort
    #       else
    #         ex = m['expect']
    #         collection = ex['collection']
    #         expect = ex['data']
    #         actual = get_entity_by_id(vals.first, collection)
    #       end

    #       if actual != expect
    #         Support::Display.error_strong("expected #{actual} to equal #{expect}")
    #       else
    #         Support::Display.info_strong("matched (#{actual} == #{expect})")
    #       end
    #     end
    #   end

    #   def get_entity_by_id(id, collection)
    #     cl = Support::Mongo.new('mongodb://127.0.0.1:27017/xadf')
    #     doc = cl.find_one_by_public_id(collection, id)
    #     Support::Display.warn("entity not found (id=#{id}; collection=#{collection})")
    #     doc ? doc.except('_id', 'public_id') : nil
    #   end
    # end

    # desc 'compute <path> [kafka_url]', 'Runs a test of a compute queue'
    # def compute(path, kafka_url)
    #   Support::Display.info("running compute test (test=#{path})")
    #   o = MultiJson.decode(IO.read(path))

    #   populate_cassandra(o.fetch('cassandra', {}))
    #   populate_mongo(o.fetch('mongo', {}))
    #   topics = o.fetch('topics', nil)
    #   if topics
    #     Support::Display.info('sending messages')
    #     produce_and_consume(topics, o.fetch('messages', []))
    #   else
    #     Support::Display.error('no topics were defined')
    #   end
    # end

    desc 'effective <document_path> <rule_path> <profile>', 'runs a test of effective rule matching'
    def effective(document_path, rule_path, profile)
      # send: rule to revisions
      # send: { "name": "validate_effect", payload: (document) } to schedule
      # wait for events on "verification" (il.emit.verification)
      # should get
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

    class SynchroEventsListener
      def initialize(events_url, ws_url)
        Support::Display.info("connecting to service (events_url=#{events_url}, ws_url=#{ws_url})", "events")
        @ready = Barrier.new
        @registered = false
        @registered_mutex = Mutex.new
        @cl = Clients::Events.new(events_url, ws_url)
        @reqs_q = Queue.new
        @req_ids_q = Queue.new
      end

      def listen
        Support::Display.info("starting events thread", "events")
        @thr = Thread.new do
          @req_ids = Set.new
          @q_req_ids = Set.new
          @cl.subscribe(['audit'], {
                          service: {
                            registered: method(:on_registered)
                          },
                          audit: {
                            notified: method(:on_notified)
                          }
                        })
        end
      end

      def thread_alive?
        @thr.join(0.75)
        @thr && @thr.alive?
      end

      def wait_until_ready
        if thread_alive?
          Support::Display.info("waiting for listener to be ready", "events")
          @registered || @ready.wait
        else
          Support::Display.warn("thread is not alive", "events")
        end
      end

      def drain_received_q
        ids = Set.new
        while !@req_ids_q.empty?
          ids << @req_ids_q.pop
        end
        ids
      end
      
      def join(expected_req_ids)
        if thread_alive?
          received_ids = drain_received_q
          if received_ids == expected_req_ids
            Support::Display.info("all requests have arrived", "events")
          else
            Support::Display.info("waiting for listener thread to exit", "events")
            expected_req_ids.each { |req_id| @reqs_q << req_id }
            if !@thr.join(10)
              Support::Display.warn("all events probably arrived early, synchronizing with events thread", "events")
              received_ids = received_ids + drain_received_q
              Support::Display.warn("mismatched request sizes (reqs=#{expected_req_ids.size}; received_ids=#{received_ids.size})", "events") if expected_req_ids.size != received_ids.size
            else
              Support::Display.info("thread finished", "events")
            end
          end
        else
          Support::Display.warn("thread is not alive", "events")
        end
      end

      private

      def on_registered(o)
        Support::Display.got_ok("event listener is ready", "events")
        @registered_mutex.synchronize { @registered = true }
        @ready.signal
        false
      end

      def on_notified(o)
        Support::Display.got_ok("received notification", "events")
        if ('execution' == o['context']['task'] && 'end' == o['context']['action'])
          req_id = o['args']['request_id']
          @req_ids << req_id
          @req_ids_q << req_id
        end

        while !@reqs_q.empty?
          @q_req_ids << @reqs_q.pop
        end

        @q_req_ids.any? && @q_req_ids.subset?(@req_ids)
      end
    end

    class Expectations
      def initialize(url)
        @qcl = Clients::Query.new(url || 'http://localhost:8000')
        @reqs = {}
      end
      
      def add(req_id, name, fn)
        Support::Display.info("adding expectations (req_id=#{name}; name=#{name}; fn=#{fn})", "expectations")
        ex = File.exist?(fn) ? MultiJson.decode(IO.read(fn)) : {}
        @reqs = @reqs.merge(req_id => { name: name, expected: ex })
      end

      def self.show_table(section, name, tbl, label=nil)
        label_s = label ? "[#{label}] " : ''
        headings = tbl.inject(Set.new) do |set, row|
          set + Set.new(row.keys)
        end
        term_table = Terminal::Table.new(
          style: { width: 120 },
          title: "#{label_s}#{section}:#{name}",
          headings: headings,
          rows: tbl.map do |row|
            headings.map { |k| row.fetch(k, nil) }
          end)
        puts term_table
        puts
      end

      def self.show_tables_from_step(step)
        step.fetch("context", {}).fetch("tables", {}).each do |section, tbls|
          tbls.each { |name, tbl| show_table(section, name, tbl) }
        end
      end

      def check
        Support::Display.info("checking (reqs=#{@reqs.size})", "expectations")
        @reqs.each do |req_id, vals|
          step = @qcl.last_step_by_request(req_id)
          if step
            ac_tables = step.fetch('context', {}).fetch('tables', {})
            ex_tables = vals[:expected].fetch('tables', [])
            ex_tables.each do |section, ex_section_tables|
              ac_section_tables = ac_tables.fetch(section, {})
              ex_section_tables.each do |name, ex_tbl|
                ac_tbl = ac_section_tables.fetch(name, nil)
                if !ac_tbl
                  Support::Display.error("expected table to exist, but not found in results (test=#{vals[:name]}; section=#{section}; name=#{name}; req_id=#{req_id}); tables=#{ac_section_tables.keys}")
                elsif ac_tbl.length != ex_tbl.length
                  Support::Display.error("expected table sizes to match (test=#{vals[:name]}; section=#{section}; name=#{name}; req_id=#{req_id}; ac_len=#{ac_tbl.length}; ex_len=#{ex_tbl.length})")
                elsif ac_tbl != ex_tbl
                  Support::Display.error("expected tables to match (test=#{vals[:name]}; section=#{section}; name=#{name}; req_id=#{req_id})")
                  Expectations::show_table(section, name, ac_tbl, 'actual')
                  Expectations::show_table(section, name, ex_tbl, 'expected')
                else
                  Expectations::show_table(section, name, ac_tbl)
                  Support::Display.info_strong("tables matched (test=#{vals[:name]}; section=#{section}; name=#{name}; req_id=#{req_id})")
                end
              end
            end
          else
            Support::Display.error("failed to find last step (test=#{vals[:name]}; req_id=#{req_id})")
          end
        end
      end
    end

    no_commands do
      def enumerate_files_in(pn, pat)
        Dir.glob(pn.join(pat)).map { |fn| Pathname.new(fn) }
      end
    end
      
    desc 'exec <path> <profile>', 'Runs a simple execute loop, uploading unpackaged rules and tables to revisions directly'
    def exec(path, profile)
      profile = MultiJson.decode(IO.read("profiles/#{profile}.json"))
      path = Pathname.new(path)
      ns = path.basename
      
      Support::Display.info_stage("profile")
      Support::Display.info("path=#{path}")      
      profile.each do |section, vs|
        Support::Display.info("#{section}")
        vs.each do |k, v|
          Support::Display.info("  #{k}: #{v}")
        end
      end
      
      cl = Clients::Revisions.new(profile['revisions']['url'])

      Support::Display.info_stage("gathering rules")
      rules = enumerate_files_in(path, '*.rule').map do |fpn|
        name = fpn.basename('.rule').to_s
        Support::Display.give('sending rule', 'test', name: name)
        cl.add_rule(ns, name, fpn.to_s)

        parsed_rule = parse_rule(IO.read(fpn.to_s))
        ver = parsed_rule.fetch('meta', {}).fetch('version', '999.999.999')
        
        { name: name, version: ver }
      end

      Support::Display.info_stage("gathering tables")
      tables = enumerate_files_in(path, '*.table').map do |fpn|
        name = fpn.basename('.table')
        data_fn = Pathname.new(fpn.dirname).join("#{name}.json").to_s
        Support::Display.give('sending table (with data)', 'test', name: name, data_fn: data_fn)
        cl.add_table(ns, name, fpn.to_s, data_fn)

        name
      end
      
      scl = Clients::Schedule.new(profile['schedule']['url'])
      sel = SynchroEventsListener.new(profile['events']['url'], profile['events']['ws_url'])
      expects = Expectations.new(profile['query']['url'])

      sel.listen
      sel.wait_until_ready

      Support::Display.info_stage("sending requests")
      req_ids = rules.inject(Set.new) do |set, rule|
        ctx_fn = File.join(path, "#{rule[:name]}.context.json")
        Support::Display.give(
          'scheduling rule test', 'test', name: rule[:name], ver: rule[:version], ctx_fn: ctx_fn
        )
        ctx = File.exist?(ctx_fn) ? JSON.parse(IO.read(ctx_fn)) : {}
        req_id = scl.execute(ns, rule[:name], rule[:version], ctx)

        expects.add(req_id, rule[:name], File.join(path, "#{rule[:name]}.expected.json"))

        set << req_id
      end

      Support::Display.info_stage("waiting")      
      sel.join(req_ids)

      Support::Display.info_stage("checking")
      expects.check
    end
  end
end
