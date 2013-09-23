require 'ahola/config'
require 'oauth'
require 'tweetstream'

module Ahola 
  class Twitter

    def self.config
      @config ||= Ahola::Config.new
    end

    def self.consumer
      return OAuth::Consumer.new(
        config[:twitter_consumer_key],
        config[:twitter_consumer_secret],
        :site => "https://api.twitter.com")
    end

    def self.tweetstream(token, secret)
      p "key: #{consumer.key}, secret: #{consumer.secret}"

      TweetStream::Client.new(
        :consumer_key => consumer.key,
        :consumer_secret => consumer.secret,
        :oauth_token => token,
        :oauth_token_secret => secret,
        :auth_method => :oauth
      )
    end
  end
end
