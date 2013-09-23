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
      TweetStream.configure do |config|
        config.consumer_key = consumer.key
        config.consumer_secret = consumer.secret
        config.oauth_token = token
        config.oauth_token_secret = secret
        config.auth_method = :oauth
      end
      TweetStream::Client.new
    end
  end
end
