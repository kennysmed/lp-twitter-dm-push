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

  Ahola::Frontend.run!
end
