require 'ahola/store'
require 'em-http'
require 'em-http/middleware/oauth'
require 'erb'

class Ahola::BergCloud
  attr_accessor :subscription_store, :registrations, :events

  def initialize
    @subscription_store = Ahola::Store::Subscription.new
    @registrations = Ahola::Store::Registration.new
    @events = Ahola::Store::Event.new
    @config = YAML.load_file('auth.yml') if File.exists?('auth.yml')
    # @counts = Hash.new {|h, k| h[k] = Hash.new(0) }
  end

  def [](key)
    key = "bergcloud_#{key}"
    ENV[key.upcase] || @config[key]
  end

  def request(url)
    credentials = {
      :consumer_key => self[:consumer_key],
      :consumer_secret => self[:consumer_secret],
      :access_token => self[:access_token],
      :access_token_secret => self[:access_token_secret]
    }
    conn = EventMachine::HttpRequest.new(url)
    conn.use EventMachine::Middleware::OAuth, credentials
    conn
  end

  # User received a direct message.
  def direct_message(id, message)
    events.direct_message!(id, message)
  end

  # def mention(id)
  #   events.mention!(id)
  # end

  # def retweet(id)
  #   events.retweet!(id)
  # end

  # def new_follower(id)
  #   events.new_follower!(id)
  # end

  # def flourish!(id)
  #   do_ahola_behaviour(id, 'flourish' => 1)
  # end


  # Check for new messages every so often.
  def start_emitting
    puts "starting to emit bergcloud messages every 10s"
    EventMachine.add_periodic_timer(10) do
      events.each do |id|
        messages = events.get_and_reset_events!(id)
        do_ahola_behaviour(id, messages)
      end
    end
  end


  # Output messages to the printer.
  def do_ahola_behaviour(id, messages)
    subscription_id, endpoint = subscription_store.get(id)

    # We'll use the messages variable in the template.
    # Each message has data which is defined and stored in
    # Event.direct_message().
    template = ERB.new(File.open('views/publication.erb', 'r').read)

    http = request(endpoint).post(
      :head => { 'Content-Type' => 'text/html; charset=utf-8' },
      :body => template.result(binding)
    )

    http.callback do
      puts "#{http.response_header.status} response for #{subscription_id}"
      if http.response_header.status == 410
        # This user has unsubscribed, so we must remove their registration.
        puts "deleting registration"
        registrations.del(id) 
      end
    end
    http.errback do
      puts "#{http.response_header.status} failed response for #{subscription_id}"
    end
  end
end
