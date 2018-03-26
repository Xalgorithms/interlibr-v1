require 'thor'

require_relative '../support/display'

module Subcommands
  class Revisions < Thor
    class_option :url, default: 'http://localhost:9292', aliases: :u

    desc 'list <what>', 'list something in the service'
    def list(what)
      
    end
  end
end
