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

    def rule(rule_id)
      resp = @conn.get("/rules/#{rule_id}")
      resp.status == 200 ? resp.body : nil
    end

    def rules_by_ns_name(ns, name)
      resp = @conn.get("/namespaces/#{ns}/rules/by_name/#{name}")
      resp.status == 200 ? resp.body : []
    end

    def rule_by_ns_name_version(ns, name, ver)
      rules_by_ns_name(ns, name).select { |rule| rule['version'] == ver }.first
    end
    
    def last_step_by_request(req_id)
      resp = @conn.get("/requests/#{req_id}/traces")
      rv = nil
      if resp.status == 200
        if resp.body && resp.body.length > 0
          rv = resp.body.first["steps"].sort do |a, b|
            if a['index'] != b['index']
              a['index'] <=> b['index']
            else
              b['phase'] == 'start' ? 1 : -1
            end
          end.last
        end
      end

      rv
    end
  end    
end
