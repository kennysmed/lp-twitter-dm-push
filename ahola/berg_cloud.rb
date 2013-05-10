require 'ahola/store'
require 'em-http'
require 'em-http/middleware/oauth'

class Ahola::BergCloud
  attr_accessor :subscription_store, :events

  def initialize
    @subscription_store = Ahola::Store::Subscription.new
    @events = Ahola::Store::Event.new
    @config = YAML.load_file('auth.yml') if File.exists?('auth.yml')
    @counts = Hash.new {|h, k| h[k] = Hash.new(0) }
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
  def direct_message(message)
    events.direct_message!(message)
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

  def flourish!(id)
    do_ahola_behaviour(id, 'flourish' => 1)
  end

  def start_emitting
    puts "starting to emit bergcloud messages every 10s"
    EventMachine.add_periodic_timer(10) do
      puts "doing it"
      events.each do |id|
        print "AN EVENT! #{id}"
      end
    end
  end

  def do_ahola_behaviour(id, counts)
    # subscription_id, endpoint = subscription_store.get(id)

    # payload = {
    #   :peeper => counts['new_followers'].to_i,
    #   :pecker => counts['retweets'].to_i,
    #   :swan => counts['mentions'].to_i,
    #   :flourish => counts['flourish'].to_i,
    # }
    # puts "#{subscription_id} sending #{payload.inspect}"

    # http = request(endpoint).post(
    #   :head => { 'Content-Type' => 'application/json' },
    #   :body => payload.to_json
    # )
    # http.callback do
    #   puts "#{http.response_header.status} response for #{subscription_id}"
    # end
    # http.errback do
    #   puts "#{http.response_header.status} failed response for #{subscription_id}"
    # end
  end
end
