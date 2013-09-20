require 'spec_helper'
require 'ahola/berg_cloud'
require 'em-rspec'
require 'uuid'
require 'webmock/rspec'


describe "BERG Cloud" do

  before :all do
    @subscription_id = '2ca7287d935ae2a6a562a3a17bdddcbe81e79d43'
    @endpoint_domain = 'api.bergcloud.com'
    @endpoint_path = "/v1/subscriptions/#{@subscription_id}/publish"
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

  describe "request" do
    before :each do
      @http = @berg_cloud.request(@endpoint)
    end

    it "requests a URL" do
      @http.should be_an_instance_of(EventMachine::HttpConnection)
      @http.uri.should eq(@endpoint)
    end

    it "requests a URL with OAuth" do
      @http.middleware[0].should be_an_instance_of(EventMachine::Middleware::OAuth)
    end
  end

  describe "post_request" do
    before :each do
      @http = @berg_cloud.post_request(@endpoint, "<p>My content</p>")
    end

    it "sends a POST request" do
      @http.req.host.should eq(@endpoint_domain)
      @http.req.uri.path.should eq(@endpoint_path)
      @http.req.method.should eq('POST')
    end

    it "sends a POST request with the correct OAuth credentials" do
      @http = @berg_cloud.post_request(@endpoint, "<p>My content</p>")
      options = @http.req.headers['Authorization'].options
      options[:consumer_key].should eq('abcdefghABCDEFGH12345')
      options[:consumer_secret].should eq('1234567890abcdefghijklmnopqrstuvwxyzABCDEF')
      options[:token].should eq('ABCDEFGHIJKLMNOPQRST')
      options[:token_secret].should eq('0987654321zyxwvutsrqponmlkjihgfedcbaZYXW')
    end

    it "sends the correct body in a POST request" do
      @http = @berg_cloud.post_request(@endpoint, "<p>My content</p>")
      @http.req.body.should eq("<p>My content</p>")
    end
  end

  describe "message_template" do
    it "uses the correct message template" do
      @berg_cloud.message_template.src.should include("<!-- Publication Template -->")
    end
  end

  describe "direct_message" do
    before :all do
      @direct_message = direct_messages[0]  # From spec_helpers.
    end

    it "sends a message to event store" do
      user_id = ::UUID.generate
      Ahola::Store::Event.stub(:direct_message!).with(user_id, @direct_message).and_return(1)
      @berg_cloud.direct_message(user_id, @direct_message).should eq(1)
    end
  end

  # TODO: All this?
  describe "start_emitting" do
    it "adds a periodic timer" do
      #@berg_cloud.start_emitting
    end

    it "periodically prints messages from the event store" do
    end

    it "tries to print any messages it fetches" do
    end
  end

  describe "print_message" do
    before :all do
      @direct_message = direct_messages[0]  # From spec_helpers.
      @user_id = ::UUID.generate
    end

    before :each do
      stub_request(:post, @endpoint).to_return(:body => 'Hello', :status => 200)
      @berg_cloud.subscription_store.stub(:get).with(@user_id).and_return(
                                                      [@subscription_id, @endpoint])

      # So that print_message can do the template.result(binding) call.
      template = double('template')
      template.stub(:result).and_return("<p>Test message</p>")
      @berg_cloud.stub(:message_template).and_return(template)
    end

    it "gets data from the subscription store" do
      @berg_cloud.subscription_store.should_receive('get').with(@user_id)
      @berg_cloud.print_message(@user_id, @direct_message)
    end

    it "should use the message template" do
      @berg_cloud.should_receive('message_template')
      @berg_cloud.print_message(@user_id, @direct_message)
    end

    it "should send a post request" do
      http = double('http')
      response_header = double('response_header')
      response_header.stub(:status).and_return(200)
      http.stub(:response_header).and_return(response_header)

      http.stub(:callback).and_yield()
      http.stub(:errback)
      @berg_cloud.stub(:post_request).with(@endpoint, "<p>Test message</p>").and_return(http)

      @berg_cloud.should_receive(:post_request).with(@endpoint, "<p>Test message</p>")
      @berg_cloud.print_message(@user_id, @direct_message)
    end

    it "does NOT delete user with a successful post" do
      # TODO: Test it does the 'puts'?
      @berg_cloud.registration_store.should_not_receive('del')
      @berg_cloud.print_message(@user_id, @direct_message)
    end

    it "deletes unsubscribed user when 410 is returned from the post" do
      http = double('http')
      response_header = double('response_header')
      response_header.stub(:status).and_return(410)
      http.stub(:response_header).and_return(response_header)

      http.stub(:callback).and_yield()
      http.stub(:errback)
      @berg_cloud.stub(:post_request).with(@endpoint, "<p>Test message</p>").and_return(http)

      @berg_cloud.registration_store.should_receive('del').with(@user_id)
      @berg_cloud.print_message(@user_id, @direct_message)
    end

    it "does nothing when the post request fails" do
      http = double('http')
      response_header = double('response_header')
      response_header.stub(:status).and_return(200)
      http.stub(:response_header).and_return(response_header)

      http.stub(:callback)
      http.stub(:errback).and_yield()
      @berg_cloud.stub(:post_request).with(@endpoint, "<p>Test message</p>").and_return(http)

      # TEST HERE.
      # TODO: Test it just does the 'puts'.
      
      @berg_cloud.print_message(@user_id, @direct_message)
    end
  end
end
