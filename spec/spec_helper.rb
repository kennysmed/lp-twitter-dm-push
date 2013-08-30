ENV["RACK_ENV"] = "test"
$LOAD_PATH.unshift(File.dirname(__FILE__) + "/..")

require 'ahola/frontend_helpers'
require 'rspec'
require 'rack/test'

RSpec.configure do |conf|
 	conf.include Rack::Test::Methods
  conf.include Ahola::FrontendHelpers
end

