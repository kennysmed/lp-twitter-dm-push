ENV["RACK_ENV"] = "test"
$LOAD_PATH.unshift(File.dirname(__FILE__) + "/..")

require 'ahola/frontend_helpers'
require 'rspec'
require 'rack/test'
require 'twitter'

RSpec.configure do |config|
  config.color_enabled = true
 	config.include Rack::Test::Methods
  config.include Ahola::FrontendHelpers

  # Force it to only accept the Rspec 2 Expect syntax.
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Example data.
  def direct_messages
    [ 
      Twitter::DirectMessage.new(
        :id => 1825786345,
        :text => "Here's my test direct message",
        :created_at => "Mon Jul 16 12:59:01 +0000 2013",
        :recipient => {
          :id => 6253282,
          :name => "Mr Receiver",
          :profile_image_url => "http://a3.twimg.com/profile_images/689684365/api_normal.png",
          :screen_name => "mrreceiver",
        },
        :sender => {
          :id => 18253293,
          :name => "Ms Sender",
          :profile_image_url => "http://a3.twimg.com/profile_images/919684372/api_normal.png",
          :screen_name => "mssender",
        }
      ),
      Twitter::DirectMessage.new(
        :id => 98765432109,
        :text => "Another direct message is here",
        :created_at => "Mon Jul 17 18:19:22 +0000 2013",
        :recipient => {
          :id => 6253282,
          :name => "Mr Receiver",
          :profile_image_url => "http://a3.twimg.com/profile_images/689684365/api_normal.png",
          :screen_name => "mrreceiver",
        },
        :sender => {
          :id => 1234567890,
          :name => "Mrs Poster",
          :profile_image_url => "http://a3.twimg.com/profile_images/827364819/api_normal.png",
          :screen_name => "mrsposter",
        }
      ),
    ]
  end
end


