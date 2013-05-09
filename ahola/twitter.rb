require 'oauth'
require 'tweetstream'

module Ahola 
  class Twitter

    def initialize
      @consumer_key = ENV['TWITTER_CONSUMER_KEY']
      @consumer_secret = ENV['TWITTER_CONSUMER_SECRET']
    end

    # def [](key)
    #   key = "twitter_#{key}"
    #   ENV[key.upcase] || @config[key]
    # end

  
    def self.consumer
      puts "CLIENT: #{@consumer_key} #{@consumer_secret}"

      return OAuth::Consumer.new(
        @consumer_key,
        @consumer_secret,
        :site => "https://api.twitter.com")
    end

    def self.tweetstream(token, secret)
      TweetStream::Client.new(
        :consumer_key => @consumer_key,
        :consumer_secret => @consumer_secret,
        :oauth_token => token,
        :oauth_token_secret => secret,
        :auth_method => :oauth
      )
    end
  end
end
