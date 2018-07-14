require 'faraday'
require 'faraday_middleware'

module Clients
  class Query
    def initialize(url)
      @conn = Faraday.new(url) do |f|
        f.request(:json) 
        f.response(:json, :content_type => /\bjson$/)
        f.adapter(Faraday.default_adapter)
      end
    end

    def last_step_by_request(req_id)
      resp = @conn.get("/requests/#{req_id}/traces")
      resp.status == 200 ? resp.body.first["steps"].sort do |a, b|
                             if a['index'] != b['index']
                               a['index'] <=> b['index']
                             else
                               b['phase'] == 'start' ? 1 : -1
                             end
                           end.last : nil
    end
  end    
end
