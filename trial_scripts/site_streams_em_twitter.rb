# TWITTER SITE STREAMS EXAMPLE (using em-twitter gem)
# Testing em-twitter without Tweetstream.
# Should print all received messages, connections, etc.

$LOAD_PATH.unshift(File.dirname(__FILE__)+'/../')
require 'em-twitter'
require 'yaml'

config = YAML.load_file('config.yml')

options = {
  # For trying tracking:
  #:path   => '/1/statuses/filter.json',
  #:params => { :track => 'yankees' },

 :path=>"/1.1/site.json",
 :params=>{:follow=>"2030131"},
  
 :host=>"sitestream.twitter.com",
 :method=>"POST",
 :on_inited=>nil,
 :proxy=>nil,
 :oauth=>
  {:consumer_key => config['twitter_consumer_key'],
   :consumer_secret => config['twitter_consumer_secret'],
   :token => config['twitter_access_token'],
   :token_secret => config['twitter_access_token_secret']}
}

EM.run do
  client = EM::Twitter::Client.connect(options)

  client.each do |result|
    puts result
  end
end

