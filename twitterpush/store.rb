require 'twitterpush/base'
require 'redis'
require 'redis-namespace'


module TwitterPush 
  module Store
    class RedisBase < TwitterPush::Base
      attr_accessor :redis

      def initialize
        if config[:rediscloud_url]
          uri = URI.parse(config[:rediscloud_url])
          redis = ::Redis.new(:host => uri.host, :port => uri.port,
                                                    :password => uri.password)
        else
          if ENV['RACK_ENV'] == 'test'
            redis = ::Redis.new(:db => 2)
          else
            # Could use db 1 for development?
            redis = ::Redis.new(:db => 0)
          end
        end
        @redis = ::Redis::Namespace.new(:twitterpush, :redis => redis)
      end

      # Empties everything from this database, so be careful!
      def flushdb
        @redis.flushdb
      end
    end


    # Keeps track of direct messages for a user.
    class Event < RedisBase
      def initialize
        super
        @redis = Redis::Namespace.new(:events, :redis => @redis)
      end

      # We keep a list of messages for each user, in case they get loads.
      def direct_message!(id, message)
        log "Store direct message"
        # This is the data about a message that we store in the database:
        m = {
              :created_at => message.created_at,
              :recipient => {
                :name => message.recipient.name,
                :profile_image_url => message.recipient.profile_image_url,
                :screen_name => message.recipient.screen_name,
              },
              :sender => {
                :name => message.sender.name,
                :profile_image_url => message.sender.profile_image_url,
                :screen_name => message.sender.screen_name,
              },
              :text => message.text,
            }
        redis.rpush(id, Marshal.dump(m))
      end

      # Get any events (eg, direct messages) that have been stored.
      # And then delete them from the store.
      def get_and_reset_messages!(id)
        log "get_and_reset_messages #{id}"
        vals = redis.multi do
          redis.lrange(id, 0, -1)
          redis.del(id)
        end
        # what a sad interface
        # vals[0] is the answer to the first statement in the block
        vals[0].map {|m| Marshal.load(m)}
      end

      def all
        redis.keys
      end

      def each(&blk)
        all.each(&blk)
      end

      def count(id)
        redis.llen(id)
      end
    end


    # Keeping a set of all the IDs who are registered with the publication.
    class Registration < RedisBase
      def add(id)
        redis.sadd('registrations', id)
        # This is a queue of new registrations that need to be added to the
        # Twitter stream.
        redis.lpush('new', id)
      end

      def each(&block)
        all.each(&block)
      end

      def all
        redis.smembers('registrations')
      end

      def del(id)
        redis.srem('registrations', id)
        # This is a queue of people who we know have unsubscribed from the
        # publication, and who we need to remove from the Twitter stream.
        redis.lpush('old', id)
      end

      def contains(id)
        redis.sismember('registrations', id)
      end

      def fresh!
        redis.del('new')
      end
    end


    # We store the data (ID and endpoint) for each LP subscription here.
    # Keyed by the uuid we've assigned to them.
    class Subscription < RedisBase
      def store(id, subscription_id, endpoint)
        redis.hset(:subscriptions, id, Marshal.dump([subscription_id, endpoint]))
      end

      def get(id)
        if data = redis.hget(:subscriptions, id)
          Marshal.load(data)
        end
      end
    end


    # Used during the Twitter authentication process.
    # We store the request token from Twitter, then delete it when the user
    # has finished the auth process.
    # Keyed by the uuid we've assigned to each user.
    class Token < RedisBase
      def store(ns, id, token)
        redis.hset(ns, id, Marshal.dump([token.token, token.secret]))
      end

      def del(ns, id)
        redis.hdel(ns, id)
      end

      def get_credentials(ns, id)
        if data = redis.hget(ns, id)
          Marshal.load(data)
        end
      end

      def get(ns, id, consumer)
        if data = get_credentials(ns, id)
          token, secret = data
          case ns
          when :request_token
            OAuth::RequestToken.new(consumer, token, secret)
          when :access_token
            OAuth::AccessToken.new(consumer, token, secret)
          end
        end
      end
    end


    # Once the user has authenticated we store their Twitter user ID and our UUID.
    # We have two hashes, so we can fetch one ID if given the other.
    class Twitter < RedisBase
      def initialize
        super
        @redis = Redis::Namespace.new(:twitter, :redis => @redis)
      end

      def store(id, twitter_id)
        log "Storing user #{id} (Twitter ID: #{twitter_id})"
        redis.hset(:twid, twitter_id, id)
        redis.hset(:uuid, id, twitter_id)
      end

      # Get our UUID from a Twitter user ID.
      def get_id(twitter_id)
        redis.hget(:twid, twitter_id)
      end

      # Get the Twitter ID from our UUID.
      def get_twitter_id(id)
        twid = redis.hget(:uuid, id)
        twid.to_i if twid
      end

      def all_twitter_ids
        redis.hkeys(:twid).map{ |id| id.to_i }
      end

      def all_ids
        redis.hkeys(:uuid)
      end

      def del_by_id(id)
        twitter_id = get_twitter_id(id)
        redis.hdel(:uuid, id)
        redis.hdel(:twid, twitter_id)
      end
    end

  end
end
