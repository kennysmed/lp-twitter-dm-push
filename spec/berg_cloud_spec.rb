require 'spec_helper'
require 'ahola/berg_cloud'
require 'em-rspec'
require 'pp'
require 'webmock/rspec'


describe "BERG Cloud" do

  before :all do
    @endpoint_domain = 'api.bergcloud.com'
    @endpoint_path = "/v1/subscriptions/2ca7287d935ae2a6a562a3a17bdddcbe81e79d43/publish"
    @endpoint = 'http://' + @endpoint_domain + @endpoint_path
  end

  before :each do
    @berg_cloud = Ahola::BergCloud.new
    stub_request(:any, @endpoint)
  end

  it "has a subscription_store" do
    @berg_cloud.subscription_store.should be_an_instance_of(Ahola::Store::Subscription)
  end

  it "has a registration_store" do
    @berg_cloud.registration_store.should be_an_instance_of(Ahola::Store::Registration)
  end

  it "has an event_store" do
    @berg_cloud.event_store.should be_an_instance_of(Ahola::Store::Event)
  end

  it "requests a URL" do
    http = @berg_cloud.request(@endpoint)
    http.should be_an_instance_of(EventMachine::HttpConnection)
    http.uri.should eq(@endpoint)
  end

  it "requests a URL with OAuth" do
    http = @berg_cloud.request(@endpoint)
    http.middleware[0].should be_an_instance_of(EventMachine::Middleware::OAuth)
  end

  it "sends a POST request" do
    http = @berg_cloud.post_request(@endpoint, "<p>My content</p>")
    http.req.host.should eq(@endpoint_domain)
    http.req.path.should eq(@endpoint_path)
    http.req.method.should eq('POST')
  end

  it "sends a POST request with the correct OAuth credentials" do
    http = @berg_cloud.post_request(@endpoint, "<p>My content</p>")
    options = http.req.headers['Authorization'].options
    options[:consumer_key].should eq('abcdefghABCDEFGH12345')
    options[:consumer_secret].should eq('1234567890abcdefghijklmnopqrstuvwxyzABCDEF')
    options[:token].should eq('ABCDEFGHIJKLMNOPQRST')
    options[:token_secret].should eq('0987654321zyxwvutsrqponmlkjihgfedcbaZYXW')
  end

  it "sends the correct body in a POST request" do
    http = @berg_cloud.post_request(@endpoint, "<p>My content</p>")
    http.req.body.should eq("<p>My content</p>")
  end

  it "uses the correct message template" do
  end

  it "stores a new direct message" do
  end

  it "periodically fetches messages" do
  end

  it "prints a message" do
  end

  it "deletes unsubscribed users" do
  end
end
