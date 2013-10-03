
# TODO:
#
# * How do we get notified a user has de-authed with our app? 
#   * If we do get notified, then we'll need to remove a user from a stream.
#   * In which case we need to map twitter_id => stream.
# * Change Ahola::Twitter.tweetstream to be .client and use app's token and secret.
#
# Need to ensure a user can only associate one twitter account with one LP.

require 'ahola/config'
require 'ahola/store'
require 'ahola/twitter'
require 'ahola/berg_cloud'
require 'eventmachine'
require 'em-http'
require 'em-hiredis'


# Call start() to kick off the streaming.
# Then poll_registrations() to keep checking for new users to stream for.
# Then start_emitting_events() to kick off printing stored messages.
class Ahola::Background
  attr_accessor :twitter_store, :bergcloud, :clients

  def initialize
    @twitter_store = Ahola::Store::Twitter.new
    @bergcloud = Ahola::BergCloud.new

    @clients = []
  end

  def config
    @config ||= Ahola::Config.new
  end

  def log(str)
    if ENV['RACK_ENV'] != 'test'
      puts str
    end
  end


  def start
    log("Starting Twitter Site Streams")
    add_initial_users(twitter_store.all_twitter_ids)
  end


  # If we were going to be starting loads of streams, we'd have to ensure
  # we only started up to 25 per second. But we're not.
  def add_initial_users(twitter_ids)
    while twitter_ids.length > 0 do
      start_new_stream( twitter_ids.slice!(0,1000) )
    end
  end


  def start_new_stream(twitter_ids)
    log("Starting new stream for #{twitter_ids.length} user(s)")

    client = new_client
        
    clients << add_first_users_to_stream(client, twitter_ids)
  end


  # Receives an array of up to 1000 Twitter IDs.
  def add_first_users_to_stream(client, twitter_ids)
    log("Adding #{twitter_ids.length} users to stream")

    # We can add up to 100 users when we first create the stream.
    client.sitestream(twitter_ids.slice!(0,100)) do |hash|
      if hash[:message][:direct_message]
        # We get DMs the user has both sent and received.
        # We only want the ones they've received.
        if hash[:for_user] == hash[:message][:direct_message][:recipient_id]
          bergcloud.direct_message(
                        Twitter::DirectMessage.new(hash[:message][:direct_message]))
        end
      end
    end

    # Users 101-1000 must be added invidiually.
    # We can only add up to 25 extra users per second to a stream.
    timer = EventMachine.add_periodic_timer(0.04) do
      if id = twitter_ids.shift
        add_user_to_client(client, id)
      else
        timer.cancel
      end
    end

    return client
  end


  def new_client
    client = Ahola::Twitter.client

    return client
  end


  def poll_registrations
    log("Polling registrations")
    em_redis.blpop('ahola:new', 0).callback do |list, new_id|
      if twitter_id = twitter_store.get_twitter_id(new_id)
        add_user(twitter_id)
      end
      EventMachine.next_tick { poll_registrations }
    end
  end


  def latest_client
    return clients.last
  end


  def add_user(twitter_id)
    if clients.length > 0
      add_user_to_client(latest_client, twitter_id)
    else
      # A rare case - no users yet so no clients have been created.
      # Probably the very first user subscribing.
      add_initial_users([twitter_id])
    end
  end


  def add_user_to_client(client, twitter_id)
    result = client.control.add_user(twitter_id)
  end


  def remove_user(twitter_id)
    # TODO: How do we know which stream to remove them from?
  end


  def start_emitting_events
    bergcloud.start_emitting
  end

  def em_redis
    @redis ||= EM::Hiredis.connect(config[:rediscloud_url] || "redis://localhost:6379")
  end
end

