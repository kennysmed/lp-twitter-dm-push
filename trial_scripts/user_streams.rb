# TWITTER USER STREAMS EXAMPLE
# No Site Streams.
# Requires the user to authenticate with the Twitter app, and then you'll need
# to put their OAuth Token and Secret below.


$LOAD_PATH.unshift(File.dirname(__FILE__)+'/../')
require 'yaml'

config = YAML.load_file('config.yml')


def start_userstream
  client = ::TweetStream::Client.new(
      :consumer_key => config['twitter_consumer_key'],
      :consumer_secret => config['twitter_consumer_secret'],
      :oauth_token => TOKENHERE,
      :oauth_token_secret => TOKENSECRETHERE,
      :auth_method => :oauth
    )

  client.on_error do |message|
    puts message
  end

  client.on_direct_message do |direct_message|
    puts direct_message.text
  end

  client.on_timeline_status  do |status|
    puts status.text
  end

  client.userstream(:with => :user)
end

start_userstream

