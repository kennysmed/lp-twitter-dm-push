$LOAD_PATH.unshift(File.dirname(__FILE__))
$stdout.sync = true

require 'thin'
require 'eventmachine'
require 'ahola/config'
require 'ahola/frontend'
require 'ahola/background'
require 'em-http'

require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/time/calculations'

processor = Ahola::Background.new
processor.setup_registrations

config = Ahola::Config.new

EM.run do
  server  = 'thin'
  host    = '0.0.0.0'
  port    = ENV['PORT'] || '5000'
  web_app = Ahola::Frontend.new

  processor.start
  processor.poll_registrations
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
