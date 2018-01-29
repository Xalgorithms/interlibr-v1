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
  end  
end
