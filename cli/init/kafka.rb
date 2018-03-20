require_relative '../support/display'
require_relative '../support/kafka'
require_relative './meta'

module Init
  class Kafka
    def self.init(opts)
      Support::Display.give("connecting to kafka (url=#{opts.url})")
      cl = ::Support::Kafka.new(opts.url)
      cl.create_topics(opts.topics)
    end
  end
end
