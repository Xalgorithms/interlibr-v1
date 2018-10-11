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
    
    def schedule(doc)
      @conn.post('/actions', { name: 'document-add', payload: doc })
    end

    def execute(ns, name, ver, ctx)
      o = {
        name: 'execute',
        args: { namespace: ns, name: name, version: ver },
        payload: ctx,
      }

      resp = @conn.post('/actions', o)
      resp.status == 200 ? resp.body['request_id'] : nil
    end
  end  
end
