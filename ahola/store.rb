require 'redis'
require 'redis-namespace'

module Ahola
  module Store
    class RedisBase
      attr_accessor :redis

      def initialize
        if ENV['REDISCLOUD_URL']
          uri = URI.parse(ENV['REDISCLOUD_URL'])
          redis = ::Redis.new(:host => uri.host, :port => uri.port,
                                                    :password => uri.password)
        else
          redis = ::Redis.new
        end
        @redis = ::Redis::Namespace.new(:ahola, :redis => redis)
      end
    end


    # Keeps track of how many mentions, retweets, etc there are for a user.
    class Event < RedisBase
      def initialize
        super
        @redis = Redis::Namespace.new(:events, :redis => @redis)
      end

      # def mention!(id, count=1)
      #   redis.hincrby(id, :mentions, count)
      # end

      # def retweet!(id, count=1)
      #   redis.hincrby(id, :retweets, count)
      # end

      # def new_follower!(id, count=1)
      #   redis.hincrby(id, :new_followers, count)
      # end

      # We keep a list of messages for each user, in case they get loads.
      def direct_message!(id, message)
        puts "store direct message"
        m = {:text => message.text,
            :sender => {
              :name => message.sender.name
              }
            }
        redis.rpush(id, Marshal.dump(m))
      end

      # def event!(id, key, count=1)
      #   redis.hincrby(id, :"#{key}s", count)
      # end

      def get_and_reset_events!(id)
        puts "get_and_reset_events #{id}"
        vals = redis.multi do
          redis.lrange(id, 0, -1)
          redis.del(id)
        end
        # what a sad interface
        # vals[0] is the answer to the first statement in the block
        # Hash[vals[0].map {|k,v| [k,v.to_i]}]
        vals[0].map {|m| Marshal.load(m)}
      end

      def all
        redis.keys
      end

      def each(&blk)
        all.each(&blk)
      end
    end


    # Keeping a set of all the IDs who are registered with the publication.
    class Registration < RedisBase
      def add(id)
        redis.sadd('registrations', id)
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
      end

      def fresh!
        redis.del('new')
      end
    end


    # We store the data (ID and endpoint) for each LP subscription here.
    # Keyed by the uuid we've assigned to them.
    class Subscription < RedisBase
      def store(id, subscription_id, endpoint)
        redis.hset(:subscription, id, Marshal.dump([subscription_id, endpoint]))
      end

      def get(id)
        if data = redis.hget(:subscription, id)
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


    # Once the user has authenticated we store their Twitter user ID and
    # screen name here.
    # Keyed by the uuid we've assigned to them.
    class TwitterData < RedisBase
      def store(id, user_id, screen_name)
        redis.hset(:twitter, id, Marshal.dump([user_id, screen_name]))
      end

      def get(id)
        if data = redis.hget(:twitter, id)
          user_id, screen_name = Marshal.load(data)
        end
        [user_id.to_i, screen_name]
      end
    end

  end
end
