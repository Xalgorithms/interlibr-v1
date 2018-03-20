require 'kafka'
require_relative './display'

module Support
  class Kafka
    def initialize(url)
      @cl = ::Kafka.new(seed_brokers: [url], client_id: 'xa-cli')
    end

    def create_topics(topics)
      topics.each do |topic|
        Support::Display.info("creating kafka topic (name=#{topic})")
        begin
          @cl.create_topic(topic)
        rescue ::Kafka::TopicAlreadyExists
          Support::Display.got_warn('topic already exists')
        end
      end
    end

    def receive_messages(topic)
      con = @cl.consumer(group_id: 'xa-cli-test-consumer')
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

    def send_single_message(topic, m)
      Support::Display.give("scheduling (topic=#{topic}; m=#{m})")
      pr = @cl.producer
      pr.produce(m, topic: topic)
      pr.deliver_messages
    end
  end
end
