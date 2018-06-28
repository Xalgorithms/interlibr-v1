require 'active_support/core_ext/hash'
require 'faker'
require 'multi_json'
require 'thor'
require 'timeout'

require_relative '../clients/revisions'
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

    desc 'exec <path> [schedule_url] [revisions_url]', 'Runs a simple execute loop, uploading unpackaged rules and tables to revisions directly'
    def exec(path, schedule_url=nil, revisions_url=nil)
      cl = Clients::Revisions.new(revisions_url || 'http://localhost:9292')
      package_name = Faker::Dune.planet.downcase.gsub(' ', '_')
      
      rules = Dir.glob(File.join(path, '*.rule')).inject({}) do |o, fn|
        puts "> sending rule (#{fn})"
        name = File.basename(fn, '.rule')
        payload = {
          meta: { version: "99.99.99", package: package_name, name: name }, 
          content: IO.read(fn),
        }
        id = cl.send_rule(payload)
        puts "< #{id}"
        id ? o.merge(name => id) : o
      end
      
      Dir.glob(File.join(path, 'tables/**/*.json')).each do |fn|
        puts "> sending table (#{fn})"
        m = fn.match(/.*\/tables\/(\w+)\/([0-9]+\.[0-9]+\.[0-9]+)\/(\w+)\.json/)
        (pkg, ver, n) = m[1..3]
        payload = {
          meta: { version: ver, package: pkg, name: n },
          content: IO.read(fn),
        }
        id = cl.send_table(payload)
        puts "< #{id}"
      end

      rules.each do |name, id|
        puts "> scheduling rule test (name=#{name}; id=#{id})"
        scl = Clients::Schedule.new(schedule_url || 'http://localhost:9000')
        req_id = scl.test_run(id, {})
        puts "> scheduled rule test (name=#{name}; id=#{id}; req_id=#{req_id})"
      end
    end
  end
end
