require 'thor'
require 'xa/ubl/auto'

require_relative '../support/display'
require_relative '../init/meta'

module Subcommands
  class Fabric < Thor
    class_option :schedule_url, default: 'http://localhost:9292', aliases: :s

    desc 'init <env>', 'Initialize a Fabric instance'
    def init(env)
      meta = Init::Meta.load(env)
      meta.init
    end
    
    desc 'submit <path>', 'Submits a document to the Fabric'
    option :raw, type: :boolean, aliases: :r
    def submit(path)
      Support::Display.give("sending #{path}")
      ::XA::UBL::Auto.parse(:invoice, path) do |doc|
        cl = Clients::Schedule.new('http://localhost:9292')
        Support::Display.got(cl.schedule(doc)) do |o|
          "scheduled"
        end
      end
    end
  end
end
