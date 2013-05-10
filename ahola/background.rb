require 'ahola/store'
require 'ahola/twitter'
require 'ahola/berg_cloud'
require 'eventmachine'
require 'em-http'
require 'em-hiredis'


class Ahola::Background
  attr_accessor :token_store, :subscription_store, :registrations, :twitter_data, :bergcloud, :clients

  def initialize
    @token_store = Ahola::Store::Token.new
    @subscription_store = Ahola::Store::Subscription.new
    @registrations = Ahola::Store::Registration.new
    @twitter_data = Ahola::Store::TwitterData.new
    @bergcloud = Ahola::BergCloud.new

    @clients = []
  end

  def setup_stream(clients, id)
    token, secret = token_store.get_credentials(:access_token, id)
    user_id, screen_name = twitter_data.get(id)
    puts "streaming #{screen_name}"

    stream = Ahola::Twitter.tweetstream(token, secret)
    clients << stream

    stream.on_direct_message do |message|
      bergcloud.direct_message(id, message)
    end

    # stream.on_timeline_status do |tweet|
    #   if tweet.retweet?
    #     rt = tweet.retweeted_status
    #     if rt.user.id == user_id
    #       bergcloud.retweet(id)
    #     end
    #   elsif tweet.user_mentions.any? { |m| m.id == user_id }
    #     bergcloud.mention(id)
    #   end
    # end

    stream.on_unauthorized do
      registrations.del(id)
      clients.delete(stream)
      puts "removing #{screen_name} from processing"
      stream.stop_stream
    end

    # stream.on_event('follow') do |follow|
    #   if follow[:target][:id] == user_id
    #     bergcloud.new_follower(id)
    #   end
    # end

    return stream
  end


  def setup_registrations
    registrations.fresh!
    registrations.each do |id|
      setup_stream(clients, id)
    end
  end


  def start
    clients.each do |client|
      client.userstream(:with => :user, :replies => :all)
    end
  end


  def poll_registrations
    puts "polling registrations"
    em_redis.blpop('ahola:new', 0).callback do |list, new_id|
      stream = setup_stream(clients, new_id) # blocking redis :/
      # stream.userstream(:with => :user, :replies => :all)
      stream.userstream(:with => :user)
      EventMachine.next_tick { poll_registrations }
    end
  end


  def start_emitting_events
    bergcloud.start_emitting
  end


  # def hourly_flourish
  #   delay = Time.now.beginning_of_hour + 1.hour - Time.now
  #   EM.add_timer(delay) do
  #     registrations.each do |id|
  #       bergcloud.flourish!(id)
  #     end
  #     hourly_flourish
  #   end
  # end


  def em_redis
    @redis ||= EM::Hiredis.connect(ENV['REDISTOGO_URL'] || "redis://localhost:6379")
  end
end
