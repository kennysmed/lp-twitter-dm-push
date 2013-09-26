require 'spec_helper'
require 'ahola/background'
require 'uuid'
require 'tweetstream'
require 'tweetstream/site_stream_client'
require 'em-rspec'


describe "Background" do
  
  before :all do
    @user_ids = [::UUID.generate, ::UUID.generate]
    @twitter_ids = [10765432100123456789, 12345]
  end

  before :each do
    @background = Ahola::Background.new
    # Start with an empty database for each test.
    redis = Ahola::Store::RedisBase.new
    redis.flushdb
    @background.twitter_store.store(@user_ids[0], @twitter_ids[0])
    @background.twitter_store.store(@user_ids[1], @twitter_ids[1])
  end

  it "starts" do
    expect(@background).to receive(:add_initial_users).with(@twitter_ids)
    @background.start
  end

  it "adds initial users" do
    expect(@background).to receive(:start_new_stream).with(@twitter_ids)
    @background.add_initial_users(@twitter_ids.dup)
  end

  it "starts a new stream" do
    expect(@background).to receive(:new_client).and_return(Ahola::Twitter.client)
    expect(@background).to receive(:add_first_users_to_stream)
      .with(instance_of(::TweetStream::Client), @twitter_ids)
      .and_return(Ahola::Twitter.client)
    @background.start_new_stream(@twitter_ids.dup)
    expect(@background.clients.first).to be_an_instance_of(::TweetStream::Client)
  end

  it "adds first users to a stream" do
    bulk_add_limit = 100
    twitter_ids = (0..bulk_add_limit+rand(50)).collect { rand(4000) }
    extras = twitter_ids[bulk_add_limit..-1]

    client = double('client')
    expect(client).to receive(:sitestream).with(twitter_ids[0...bulk_add_limit])

    client_control = double('client_control')
    expect(client).to receive(:control).exactly(extras.length).times.and_return(client_control)
    expect(client_control).to receive(:add_user).exactly(extras.length).times.and_return {extras.shift}

    @background.add_first_users_to_stream(client, twitter_ids)
  end

  it "creates a new Twitter client" do
    expect(@background.new_client).to be_an_instance_of(::TweetStream::Client)
  end

  # TODO: Don't know how to test the Event Machine stuff.
  it "polls registrations" do
  end

  describe "with several clients" do
    before :each do
      @num_clients = 4
      client = double('client')
      client_control = double('client_control')
      client.stub(:control).and_return(client_control)
      (1..@num_clients).each do |n|
        # A fake method, so we can tell which client is which.
        client.stub(:id) { n }
        @background.clients << client
      end
    end

    it "returns the latest client" do
      expect(@background.latest_client.id).to eq(@num_clients) 
    end

    it "adds a user to the latest client" do
      client = @background.clients.last
      expect(@background).to receive(:add_user_to_client).with(client, @twitter_ids[0])
      @background.add_user(@twitter_ids[0])
    end

    it "adds a user to a client" do
      client = @background.clients.last
      expect(client.control).to receive(:add_user).with(@twitter_ids[0])
      @background.add_user_to_client(client, @twitter_ids[0])
    end
  end

  it "adds a user when there are no clients" do
    expect(@background).to receive(:add_initial_users).with([@twitter_ids[0]])
    @background.add_user(@twitter_ids[0])
  end

  # TODO:
  #it "removes a user" do
  #end

  it "starts emitting events" do
    expect(@background.bergcloud).to receive(:start_emitting)
    @background.start_emitting_events
  end

  it "has a redis" do
    expect(@background.em_redis).to be_an_instance_of(EventMachine::Hiredis::Client)
  end

end

