require 'ahola/config'
require 'ahola/twitter'
require 'ahola/berg_cloud'


# A wrapper for handling Twitter Site Streams. Starting them, adding and
# removing users, etc.
# Partly because of the complications of only allowing 1000 users per Site
# Stream, and so having to keep track of which user is in which stream, in case
# we need to remove them.
class Ahola::Streamer
  attr_accessor :bergcloud, :clients, :accounts, :latest_client_id, :max_users_per_stream

  def initialize
    @bergcloud = Ahola::BergCloud.new

    # Will be client_id => Twitter Client
    # Where client_id is a made up number, just so we can identify which client
    # is which.
    @clients = {}

    # Will be twitter_id => client_id.
    # So that we know which twitter account is being streamed by which Client.
    @accounts = {}
    
    # The client_id of the most recent client, so we know which client to add
    # new twitter IDs to.
    @latest_client_id = 0

    # Twitter restricts each Site Stream to this many users.
    @max_users_per_stream = 1000
  end

  def config
    @config ||= Ahola::Config.new
  end

  def log(str)
    if ENV['RACK_ENV'] != 'test'
      puts str
    end
  end


  # If we were going to be starting loads of streams, we'd have to ensure
  # we only started up to 25 per second. But we're not.
  def start(twitter_ids)
    log("Starting Site Streams")

    while twitter_ids.length > 0 do
      start_new_stream( twitter_ids.slice!(0,max_users_per_stream) )
    end
  end


  def start_new_stream(twitter_ids)
    log("Starting new stream for #{twitter_ids.length} user(s)")

    client = new_client
    client_id = new_client_id

    clients[client_id] = add_first_users_to_stream(client, twitter_ids)
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
    Ahola::Twitter.client
  end


  def latest_client
    return clients[latest_client_id]
  end
  

  def add_user(twitter_id)
    log("Adding Twitter ID #{twitter_id}")
    if clients.keys.length > 0 && latest_client_has_room?
      add_user_to_client(latest_client, twitter_id)
    else
      # Either, the latest client is full, so need to start a new one.
      # Or:
      # A rare case - no users at all yet so no clients have been created.
      # Probably the very first user subscribing.
      start_new_stream([twitter_id])
    end
  end

  
  def remove_user(twitter_id)
    if client = client_for_id(twitter_id)
      log("Removing Twitter ID #{twitter_id}")
      client.remove_user(twitter_id)
    end
  end


  def client_for_id(twitter_id)
    if client_id = accounts[twitter_id]
      if clients[client_id]
        return clients[client_id]
      end
    end
    # Shouldn't happen but, you know.
    return false
  end


  # Has room to add new users to the latest client?
  def latest_client_has_room?
    if accounts.values.count{ |c| c == latest_client_id } < max_users_per_stream
      true
    else
      false
    end
  end


  def add_user_to_client(client, twitter_id)
    result = client.control.add_user(twitter_id)
  end


  # This seems a bit noddy.
  # Just making a new fake ID for each client, counting up from 1.
  def new_client_id
    if clients.keys.length > 0
      new_id = clients.keys.max + 1
    else
      new_id = 1
    end

    latest_client = new_id

    return new_id
  end

end
