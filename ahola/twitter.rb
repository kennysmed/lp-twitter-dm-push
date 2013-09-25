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

    def self.client()
      ::TweetStream::Client.new(
        :consumer_key => consumer.key,
        :consumer_secret => consumer.secret,
        :oauth_token => config[:twitter_access_token],
        :oauth_token_secret => config[:twitter_access_token_secret],
        :auth_method => :oauth
      )
    end
  end
end
