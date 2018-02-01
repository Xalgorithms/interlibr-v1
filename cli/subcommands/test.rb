require 'cassandra'
require 'kafka'
require 'multi_json'
require 'thor'
require 'timeout'

require_relative '../support/display'

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

      def truncate_tables(sess, ns)
        ns.each do |n|
          Support::Display.warn("clearing data (table=#{n})")
          stm = sess.prepare("TRUNCATE TABLE #{n}")
          sess.execute(stm)
        end
      end

      def make_session
        cl = Cassandra.cluster(hosts: ['localhost'], port: 9042)
        cl.connect('xadf')
      end
      
      def populate_cassandra(o)
        Support::Display.info('initializing cassandra data')
        sess = make_session
        truncate_tables(sess, o.keys)
        inserts = o.keys.inject([]) do |a, tn|
          a + o.fetch(tn, []).map do |r|
            ks = r.keys
            vs = ks.map { |k| "'#{r[k]}'" }
            "INSERT INTO #{tn} (#{ks.join(',')}) VALUES (#{vs.join(',')})"
          end
        end

        Support::Display.info('inserting test data')
        q = 'BEGIN BATCH ' + inserts.join(';') + ' APPLY BATCH;'
        stm = sess.prepare(q)
        sess.execute(stm)
      end

      def connect_kafka
        Kafka.new(seed_brokers: ['localhost:9092'], client_id: 'xa-cli (test)')
      end
      
      def send_single_message(topic, m)
        Support::Display.give("scheduling (topic=#{topic}; m=#{m})")
        kafka = connect_kafka
        pr = kafka.producer
        pr.produce(m, topic: topic)
        pr.deliver_messages
      end

      def receive_messages(topic)
        kafka = connect_kafka
        con = kafka.consumer(group_id: 'xa-cli-test-consumer')
        con.subscribe(topic, start_from_beginning: false)

        vals = []
        begin
          Support::Display.info("waiting for messages (topic=#{topic})")
          Timeout::timeout(10) do
            con.each_message do |m|
              Support::Display.got_ok("value=#{m.value}")
              vals = vals + [m.value]
            end
          end
        rescue
          Support::Display.info('finished waiting')
          con.stop
        end

        vals
      end
      
      def produce_and_consume(topics, msgs)
        msgs.each do |m|
          send_single_message(topics['in'], m['in'])
          vals = receive_messages(topics['out']).sort
          expect = m['out'].sort
          if vals != expect
            Support::Display.error_strong("expected #{vals} to equal #{expect}")
          else
            Support::Display.info_strong("matched (#{vals} == #{expect})")
          end
        end
      end
    end
    
    desc 'compute <path>', 'Runs a test of a compute queue'
    def compute(path)
      Support::Display.info("running compute test (test=#{path})")
      o = MultiJson.decode(IO.read(path))

      populate_cassandra(o.fetch('cassandra', {}))
      topics = o.fetch('topics', nil)
      if topics
        Support::Display.info('sending messages')
        produce_and_consume(topics, o.fetch('messages', []))
      else
        Support::Display.error('no topics were defined')
      end
    end
  end
end
