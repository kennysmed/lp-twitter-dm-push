$LOAD_PATH.unshift(File.dirname(__FILE__))
$stdout.sync = true

require 'thin'
require 'eventmachine'
require 'ahola/frontend'
require 'ahola/background'
require 'em-http'

require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/time/calculations'

processor = Ahola::Background.new
processor.setup_registrations

keepalive_time = ENV['AHOLA_KEEPALIVE'] || 1200
keepalive_url = ENV['AHOLA_URL']

EM.run do
  processor.start
  processor.poll_registrations
  processor.start_emitting_events
  # processor.hourly_flourish

  if keepalive_url
    EM.add_periodic_timer(keepalive_time) do
      http = EventMachine::HttpRequest.new(keepalive_url).get.callback do
        puts "keepalive: #{http.response_header.status}"
      end
    end
  end
  Ahola::Frontend.run!
end
