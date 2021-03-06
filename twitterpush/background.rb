require 'twitterpush/base'
require 'twitterpush/store'
require 'twitterpush/streamer'
require 'twitterpush/berg_cloud'
require 'eventmachine'
require 'em-http'
require 'em-hiredis'


# Call start() to kick off the streaming.
# Then poll_registrations() to keep checking for new users to stream for,
# and poll_deregistrations() for users we should remove.
# Then start_emitting_events() to kick off printing stored messages.
module TwitterPush
  class Background < TwitterPush::Base
    attr_accessor :twitter_store, :bergcloud, :streamer

    def initialize
      @twitter_store = TwitterPush::Store::Twitter.new
      @bergcloud = TwitterPush::BergCloud.new
      @streamer = TwitterPush::Streamer.new
    end


    def start
      log("Starting Background processes")
      streamer.start(twitter_store.all_twitter_ids)
    end


    # When there are new registrations in the 'new' list, add to the stream.
    def poll_registrations
      log("Polling registrations")
      em_redis.blpop('twitterpush:new', 0).callback do |list, new_id|
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
      em_redis.blpop('twitterpush:old', 0).callback do |list, old_id|
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
end
