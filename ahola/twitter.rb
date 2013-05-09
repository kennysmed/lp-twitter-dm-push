require 'oauth'
require 'tweetstream'

module Ahola 
  class Twitter

      def initialize
        @config = YAML.load_file('auth.yml') if File.exists?('auth.yml')
      end

      def [](key)
        key = "twitter_#{key}"
        ENV[key.upcase] || @config[key]
      end


      def self.consumer
        config = new
        return OAuth::Consumer.new(config[:consumer_key],
          config[:consumer_secret],
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
