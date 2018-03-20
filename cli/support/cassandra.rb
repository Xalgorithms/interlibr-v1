require 'cassandra'
require_relative './display'

module Support
  class Cassandra
    def initialize(url, keyspace = nil)
      @cl = ::Cassandra.cluster(hosts: ['localhost'], port: 9042)
      @sess = keyspace ? @cl.connect(keyspace) : @cl.connect
    end

    def execute(statements)
      statements.each do |stm|
        Support::Display.give("running statement: #{stm}")
        @sess.execute(@sess.prepare(stm))
      end
    end

    def execute_batch(statements)
      batch = @sess.batch do |b|
        statements.each do |stm|
          Support::Display.info("adding statement: #{stm}")
          b.add(stm)
        end
      end

      Support::Display.give('sending batch')
      @sess.execute(batch)
    end

    def truncate_tables(ns)
      execute(ns.map { |n| "TRUNCATE TABLE #{n}" })
    end
  end
end
