require 'twitterpush/base'
require 'twitterpush/store'
require 'em-http'
require 'em-http/middleware/oauth'
require 'erb'


module TwitterPush 
  class BergCloud < TwitterPush::Base
    attr_accessor :subscription_store, :registration_store, :twitter_store, :event_store, :background, :emitting_timer_seconds

    def initialize
      @event_store = TwitterPush::Store::Event.new
      @registration_store = TwitterPush::Store::Registration.new
      @subscription_store = TwitterPush::Store::Subscription.new
      @twitter_store = TwitterPush::Store::Twitter.new

      # How frequently we do the emitting of direct messages.
      # It's here mainly so we can set it to a small amount when testing.
      @emitting_timer_seconds = 10
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
            # Don't remove from twitter_store yet, because we'll need the twitter
            # ID to remove them from the stream.
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
end
