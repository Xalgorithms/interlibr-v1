require 'faraday'
require 'faraday_middleware'

module Clients
  class Schedule
    def initialize(url)
      @conn = Faraday.new(url) do |f|
        f.request(:json) 
        f.response(:json, :content_type => /\bjson$/)
        f.adapter(Faraday.default_adapter)
      end
    end
    
    def execute(ns, name, ver, ctx)
      o = {
        name: 'execute',
        args: { namespace: ns, name: name, version: ver },
        document: ctx,
      }

      resp = @conn.post('/actions', o)
      resp.status == 200 ? resp.body['request_id'] : nil
    end

    def verify_effective(doc, ctxs)
      o = {
        name: 'verify',
        args: { what: 'effective' },
        document: { content: doc, effective_contexts: ctxs },
      }

      resp = @conn.post('/actions', o)
      resp.status == 200 ? resp.body['request_id'] : nil
    end

    def verify_applicable(rule_id, doc)
      o = {
        name: 'verify',
        args: { what: 'applicable', rule_id: rule_id },
        document: { content: doc },
      }

      resp = @conn.post('/actions', o)
      resp.status == 200 ? resp.body['request_id'] : nil
    end
  end  
end
