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

    def execute_adhoc(rule_id, ctx)
      payload = {
        name: 'execute_rule_adhoc',
        args: { rule_id: rule_id },
        payload: ctx,
      }

      resp = @conn.post('/actions', payload)
      resp.status == 200 ? resp.body['request_id'] : nil
    end
  end  
end
