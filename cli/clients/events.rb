require 'eventmachine'
require 'faraday'
require 'faraday_middleware'
require 'faye/websocket'
require 'multi_json'

require_relative '../support/display'

module Clients
  class Events
    def initialize(url_api, url_ws)
      @conn = Faraday.new(url_api) do |f|
        f.request(:json) 
        f.response(:json, :content_type => /\bjson$/)
        f.adapter(Faraday.default_adapter)
      end
      @url_ws = url_ws
    end

    def subscribe(topics, fns)
      Support::Display.give("subscribing (topics=#{topics})", "events_client")
      resp = @conn.post('/subscriptions', topics: topics)
      if resp.status == 200
        Support::Display.give("listening (url=#{resp.body['url']})", "events_client")
        EM.run do
          url = "#{@url_ws}#{resp.body['url']}"
          Support::Display.give("connecting socket (url=#{url})", "events_client")
          ws = Faye::WebSocket::Client.new(url)
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
            Support::Display.got_ok("socket closed", "events_client")
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
