# TWITTER SITE STREAMS EXAMPLE (using Tweetstream gem)
# Will print out text of DMs and statuses, and do some adding/removing of
# a user.

$LOAD_PATH.unshift(File.dirname(__FILE__)+'/../')
require 'ahola/twitter'
require 'eventmachine'
require 'tweetstream'
require 'yaml'

config = YAML.load_file('config.yml')

user_id = 2030131 # philgyfordtest
user_id_to_add = '12552' # philgyford
user_id_to_remove = '12552' # philgyford


TweetStream.configure do |conf|
  conf.consumer_key       = config['twitter_consumer_key']
  conf.consumer_secret    = config['twitter_consumer_secret']
  conf.oauth_token        = config['twitter_access_token']
  conf.oauth_token_secret = config['twitter_access_token_secret']
  conf.auth_method        = :oauth
end

EM.run do

  client = TweetStream::Client.new

  def on_direct_message(message)
    p message.text
  end

  def on_timeline_status(status)
    p status.text
  end


  client.sitestream([user_id], :followings => true) do |hash|
    # Because TweetStream::Client.respond_to() doesn't seem to work with
    # site streams, we can't use hooks, and need to handle individual
    # event types like this:

    if hash[:message][:direct_message]
      on_direct_message(Twitter::DirectMessage.new(hash[:message][:direct_message]))
    elsif hash[:message][:text] && hash[:message][:user]
      on_timeline_status(Twitter::Tweet.new(hash[:message]))
    end
  end


  EM::Timer.new(20) do
    puts "Adding #{user_id_to_add}"
    client.control.add_user([user_id_to_add])
  end

  EM::Timer.new(80) do
    puts "Getting info"
    # Might fail because it can take "up to a minute" for this to work correctly.
    client.control.info { |i| puts i.inspect }
  end

  EM::Timer.new(90) do
    client.control.friends_ids(user_id) do |friends|
      puts "Inspecting friends"
      puts friends.inspect
    end
  end

  EM::Timer.new(120) do
    puts "Removing #{user_id_to_add}"
    client.control.remove_user([user_id_to_remove])
    puts "Getting info"
    client.control.info { |i| puts i.inspect }
  end

end

