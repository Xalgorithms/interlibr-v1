require 'faraday'
require 'faraday_middleware'

require_relative '../support/display'

module Clients
  class Revisions
    def initialize(url)
      @conn = Faraday.new(url) do |f|
        f.request(:json) 
        f.response(:json, :content_type => /\bjson$/)
        f.adapter(Faraday.default_adapter)
      end
    end
    
    def add_rule(ns, name, content_fn)
      Support::Display.info('adding rule', 'revisions-client', ns: ns, name: name, fn: content_fn)
      add('rule', ns: ns, name: name, data: IO.read(content_fn))
    end

    def remove_rule(ns, name, ver, origin, branch)
      args = {
        ns: ns,
        name: name,
        version: ver,
        origin: origin,
        branch: branch,
      }
      Support::Display.info('removing rule', 'revisions-client', args)
      remove('rule', args)
    end

    def add_table(ns, name, content_fn)
      Support::Display.info('adding table', 'revisions-client', ns: ns, name: name, fn: content_fn)
      add('table', ns: ns, name: name, data: IO.read(content_fn))
    end

    def remove_table(ns, name, ver, origin, branch)
      args = {
        ns: ns,
        name: name,
        version: ver,
        origin: origin,
        branch: branch,
      }
      Support::Display.info('removing table', 'revisions-client', args)
      remove('table', args)
    end

    def add_data(ns, name, fn)
      args = {
        ns: ns,
        name: name,
        type: 'json',
        data: IO.read(fn),
      }
      Support::Display.info('adding data', 'revisions-client', args)
      add('data', args)
    end
    
    def remove_data(ns, name, origin, branch)
      args = {
        ns: ns,
        name: name,
        origin: origin,
        branch: branch,
      }
      Support::Display.info('removing data', 'revisions-client', args)
      remove('data', args)
    end
    
    def add_repo(url)
      Support::Display.info('adding repository', 'revisions-client', url: url)
      add('repository', url: url)
    end

    private

    def add(th, args)
      act_on_thing('add', th, args)
    end

    def remove(th, args)
      act_on_thing('remove', th, args)
    end
    
    def act_on_thing(act, th, args)
      o = {
        name: act,
        thing: th,
        args: args,
      }

      Support::Display.give("POSTing #{act}", 'revisions-client', th: th)
      res = @conn.post('/actions', o)
      Support::Display.got(res) do
        ["POSTed #{act}", 'revisions-client', th: th]
      end
    end
  end
end
