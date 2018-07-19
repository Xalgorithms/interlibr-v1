require 'eventmachine'
require 'faraday'
require 'faraday_middleware'
require 'faye/websocket'
require 'multi_json'

require_relative '../support/display'

module Clients
  class Events
    def initialize(url)
      @conn = Faraday.new(url) do |f|
        f.request(:json) 
        f.response(:json, :content_type => /\bjson$/)
        f.adapter(Faraday.default_adapter)
      end
    end

    def subscribe(topics, fns)
      resp = @conn.post('/subscriptions', topics: topics)
      if resp.status == 200
        Support::Display.give("listening (url=#{resp.body['url']})", "events_client")
        EM.run do
          ws = Faye::WebSocket::Client.new("ws://localhost:8888#{resp.body['url']}")
          ws.on(:open) do |evt|
            #            p [:open, evt]
            ws.send(MultiJson.encode(name: 'confirm', payload: { id: resp.body['id'] }))
          end

          ws.on(:message) do |evt|
            Support::Display.got_ok("received message", "events_client")
            o = MultiJson.decode(evt.data)
            fn = fns.fetch(o['topic'].to_sym, {}).fetch(o['effect'].to_sym, nil)
#            p [:message, o]
            if fn && fn.call(o['payload'])
              ws.close
            end
          end

          ws.on(:close) do |evt|
            #            p [:close, evt]
            ws = nil
            EM.stop
          end
        end

        Support::Display.give("unsubscribing", "events_client")
        r = @conn.delete("/subscriptions/#{resp.body['id']}")
        Support::Display.got_ok("unsubscribed", "events_client")
      end
    end

    def unsubscribe()
    end
  end
end
