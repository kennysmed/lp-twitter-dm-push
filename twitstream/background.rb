
# TODO:
#
# * How do we get notified a user has de-authed with our app? 
#   * If we do get notified, then we'll need to remove a user from a stream.
#   * In which case we need to map twitter_id => stream.
# * Change Twitstream::Twitter.tweetstream to be .client and use app's token and secret.
#
# Need to ensure a user can only associate one twitter account with one LP.

require 'twitstream/config'
require 'twitstream/store'
require 'twitstream/streamer'
require 'twitstream/berg_cloud'
require 'eventmachine'
require 'em-http'
require 'em-hiredis'


# Call start() to kick off the streaming.
# Then poll_registrations() to keep checking for new users to stream for,
# and poll_deregistrations() for users we should remove.
# Then start_emitting_events() to kick off printing stored messages.
class Twitstream::Background
  attr_accessor :twitter_store, :bergcloud, :streamer

  def initialize
    @twitter_store = Twitstream::Store::Twitter.new
    @bergcloud = Twitstream::BergCloud.new
    @streamer = Twitstream::Streamer.new
  end

  def config
    @config ||= Twitstream::Config.new
  end

  def log(str)
    if ENV['RACK_ENV'] != 'test'
      puts str
    end
  end


  def start
    log("Starting Background processes")
    streamer.start(twitter_store.all_twitter_ids)
  end


  # When there are new registrations in the 'new' list, add to the stream.
  def poll_registrations
    log("Polling registrations")
    em_redis.blpop('twitstream:new', 0).callback do |list, new_id|
      if twitter_id = twitter_store.get_twitter_id(new_id)
        streamer.add_user(twitter_id)
      end
      EventMachine.next_tick {
        poll_registrations
      }
    end
  end


  # When there are new deregistrations (a user has unsubbed), remove from stream.
  def poll_deregistrations
    log("Polling deregistrations")
    em_redis.blpop('twitstream:old', 0).callback do |list, old_id|
      if twitter_id = twitter_store.get_twitter_id(old_id)
        streamer.remove_user(twitter_id)
        twitter_store.del_by_id(old_id)
      end
      EventMachine.next_tick {
        poll_deregistrations
      }
    end
  end


  def start_emitting_events
    bergcloud.start_emitting
  end


  def em_redis
    @redis ||= EM::Hiredis.connect(config[:rediscloud_url] || "redis://localhost:6379")
  end
end

