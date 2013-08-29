require 'ahola/config'
require 'oauth'
require 'tweetstream'

module Ahola 
  class Twitter

    def config
      @config ||= Ahola::Config.new
    end

    def self.consumer
      p "KEY: #{config[:twitter_consumer_key]}"
      return OAuth::Consumer.new(
        config[:twitter_consumer_key],
        config[:twitter_consumer_secret],
        :site => "https://api.twitter.com")
    end

    def self.tweetstream(token, secret)
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
