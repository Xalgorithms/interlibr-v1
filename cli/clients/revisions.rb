require 'faraday'
require 'faraday_middleware'

module Clients
  class Revisions
    def initialize(url)
      @conn = Faraday.new(url) do |f|
        f.request(:json) 
        f.response(:json, :content_type => /\bjson$/)
        f.adapter(Faraday.default_adapter)
      end
    end
    
    def send_rule(content)
      res = @conn.post('/rules', content)
      res.status == 200 ? res.body["id"] : nil
    end
    
    def send_table(content)
      res = @conn.post('/tables', content)
      res.status == 200 ? res.body["id"] : nil
    end
  end  
end
