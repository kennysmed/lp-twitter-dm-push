require 'ahola/config'
require 'ahola/store'
require 'em-http'
require 'em-http/middleware/oauth'
require 'erb'

class Ahola::BergCloud
  attr_accessor :subscription_store, :registration_store, :event_store

  def initialize
    @subscription_store = Ahola::Store::Subscription.new
    @registration_store = Ahola::Store::Registration.new
    @event_store = Ahola::Store::Event.new
  end

  def config
    @config ||= Ahola::Config.new
  end

  def log(str)
    if ENV['RACK_ENV'] != 'test'
      puts str
    end
  end

  def request(url)
    credentials = {
      :consumer_key => config[:bergcloud_consumer_key],
      :consumer_secret => config[:bergcloud_consumer_secret],
      :access_token => config[:bergcloud_access_token],
      :access_token_secret => config[:bergcloud_access_token_secret]
    }
    conn = EventMachine::HttpRequest.new(url)
    conn.use EventMachine::Middleware::OAuth, credentials
    conn
  end

  def post_request(url, body)
    request(url).post(
      :head => { 'Content-Type' => 'text/html; charset=utf-8' },
      :body => body
    )
  end

  def message_template
    # We'll use the messages variable in the template.
    # Each message has data which is defined and stored in
    # Event.direct_message().
    ERB.new(File.open('views/publication.erb', 'r').read)
  end

  # User received a direct message.
  def direct_message(id, message)
    event_store.direct_message!(id, message)
  end

  # Check for new messages every so often.
  def start_emitting
    log("starting to emit bergcloud messages every 10s")
    EventMachine.add_periodic_timer(10) do
      event_store.each do |id|
        messages = event_store.get_and_reset_messages!(id)
        print_message(id, messages)
      end
    end
  end

  def print_message(id, messages)
    subscription_id, endpoint = subscription_store.get(id)

    template = message_template

    begin
      http = post_request(endpoint, template.result(binding))

      http.callback do
        log("#{http.response_header.status} response for #{subscription_id}")
        if http.response_header.status == 410
          # This user has unsubscribed, so we must remove their registration.
          log("deleting registration")
          registration_store.del(id) 
        end
      end
      http.errback do
        log("#{http.response_header.status} failed response for #{subscription_id}")
      end
    rescue => e
      log("ERROR: #{e}")
    end
  end
end
