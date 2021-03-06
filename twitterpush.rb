$LOAD_PATH.unshift(File.dirname(__FILE__))
$stdout.sync = true

require 'thin'
require 'eventmachine'
require 'twitterpush/config'
require 'twitterpush/frontend'
require 'twitterpush/background'
require 'em-http'

require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/time/calculations'

processor = TwitterPush::Background.new
config = TwitterPush::Config.new

EM.run do
  server  = 'thin'
  host    = '0.0.0.0'
  port    = ENV['PORT'] || '5000'
  web_app = TwitterPush::Frontend.new

  processor.start
  processor.poll_registrations
  processor.poll_deregistrations
  processor.start_emitting_events

  if config[:base_url]
    EM.add_periodic_timer(config[:keepalive_time] || 1200) do
      http = EventMachine::HttpRequest.new(config[:base_url]).get.callback do
        puts "keepalive: #{http.response_header.status}"
      end
    end
  end

  dispatch = Rack::Builder.app do
    map '/' do
      run web_app
    end
  end

  Rack::Server.start({
    app:    dispatch,
    server: server,
    Host:   host,
    Port:   port
  })
end
