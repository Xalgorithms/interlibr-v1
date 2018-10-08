require 'thor'

require_relative '../clients/revisions'
require_relative '../support/display'

module Subcommands
  class Revisions < Thor
    class_option :url, default: 'http://localhost:9292', aliases: :u

    desc 'add_rule <ns> <name> <fn>', 'add a rule to the revisions service'
    def add_rule(ns, name, fn)
      cl = Clients::Revisions.new(options[:url])
      cl.add_rule(ns, name, fn)
    end

    desc 'remove_rule <ns> <name> <version> [origin] [branch]', 'add a rule to the revisions service'
    def remove_rule(ns, name, ver, origin='origin:adhoc', branch='branch:adhoc')
      cl = Clients::Revisions.new(options[:url])
      cl.remove_rule(ns, name, ver, origin, branch)
    end

    desc 'add_table <ns> <name> <fn>', 'add a table to the revisions service'
    def add_table(ns, name, fn)
      cl = Clients::Revisions.new(options[:url])
      cl.add_table(ns, name, fn)
    end

    desc 'remove_table <ns> <name> <version> [origin] [branch]', 'add a table to the revisions service'
    def remove_table(ns, name, ver, origin='origin:adhoc', branch='branch:adhoc')
      cl = Clients::Revisions.new(options[:url])
      cl.remove_table(ns, name, ver, origin, branch)
    end

    desc 'add_data <ns> <name> <json_fn>', 'add a table to the revisions service'
    def add_data(ns, name, fn)
      cl = Clients::Revisions.new(options[:url])
      cl.add_data(ns, name, fn)
    end

    desc 'remove_data <ns> <name> [origin] [branch]', 'add a table to the revisions service'
    def remove_data(ns, name, origin='origin:adhoc', branch='branch:adhoc')
      cl = Clients::Revisions.new(options[:url])
      cl.remove_data(ns, name, origin, branch)
    end

    desc 'add_repository <repo_url>', 'add a github repo to the revisions service'
    def add_repository(repo_url)
      cl = Clients::Revisions.new(options[:url])
      cl.add_repo(repo_url)
    end
  end
end
