# require 'ahola/store'
# require 'ahola/twitter'
# require 'ahola/berg_cloud'
require 'eventmachine'
require 'em-http'
require 'em-hiredis'


class Ahola::Background
  attr_accessor :token_store, :subscription_store, :registrations, :twitter_data, :bergcloud, :clients

  def initialize
    # @token_store = Kachina::Store::Token.new
    # @subscription_store = Kachina::Store::Subscription.new
    # @registrations = Kachina::Store::Registration.new
    # @twitter_data = Kachina::Store::TwitterData.new
    # @bergcloud = Kachina::BergCloud.new

    # @clients = []
  end


  def setup_registrations
    # registrations.fresh!
    # registrations.each do |id|
    #   setup_stream(clients, id)
    # end
  end


  def start
    # clients.each do |client|
    #   client.userstream(:with => :user, :replies => :all)
    # end
  end
end
