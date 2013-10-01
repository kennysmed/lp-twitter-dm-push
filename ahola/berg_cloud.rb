require 'ahola/config'
require 'ahola/store'
require 'em-http'
require 'em-http/middleware/oauth'
require 'erb'

class Ahola::BergCloud
  attr_accessor :subscription_store, :registration_store, :twitter_store, :event_store, :emitting_timer_seconds

  def initialize
    @event_store = Ahola::Store::Event.new
    @registration_store = Ahola::Store::Registration.new
    @subscription_store = Ahola::Store::Subscription.new
    @twitter_store = Ahola::Store::Twitter.new

    # How frequently we do the emitting of direct messages.
    # It's here mainly so we can set it to a small amount when testing.
    @emitting_timer_seconds = 10
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
  def direct_message(message)
    if id = twitter_store.get_id(message.recipient.id)
      event_store.direct_message!(id, message)
    end
  end

  # Check for new messages every so often.
  def start_emitting
    log("Starting to emit bergcloud messages every #{emitting_timer_seconds}s")
    EventMachine.add_periodic_timer(emitting_timer_seconds) do
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
          log("Deleting registration")
          registration_store.del(id)
          twitter_store.del_by_id(id)
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
