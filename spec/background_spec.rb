require 'spec_helper'
require 'ahola/background'
require 'uuid'
require 'tweetstream'
require 'tweetstream/site_stream_client'


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
    client = Ahola::Twitter.client
    expect(client).to receive(:sitestream).with(@twitter_ids)
    returned = @background.add_first_users_to_stream(client, @twitter_ids.dup)
    expect(returned).to eq(client)
  end

  it "adds many first useres to a stream" do
    twitter_ids = *(1..110)
    client = Ahola::Twitter.client
    client.stub(:sitestream)


    # TODO: Can't work out how to stub / test client.control.add_user()
    client.stub(:control).stub(:add_user).and_return('hi')
    TweetStream::SiteStreamClient.any_instance.stub(:add_user)
    p client.control.add_user
    expect(client.control).to receive(:add_user).with(101)


    @background.add_first_users_to_stream(client, @twitter_ids.dup)
  end



  it "adds large numbers of users via control streams" do
    ::TweetStream::Client.any_instance.stub(:sitestream)
    ::TweetStream::SiteStreamClient.any_instance.stub(:add_user)
    @background.start_new_stream( (1..110).to_a )


  end

  it "creates a new Twitter client" do
  end

  it "polls registrations" do
  end

  it "returns the latest client" do
  end

  it "adds a user" do
  end

  it "removes a user" do
  end

  it "starts emitting events" do
  end

end

