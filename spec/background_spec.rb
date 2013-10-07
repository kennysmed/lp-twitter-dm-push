require 'spec_helper'
require 'twitstream/background'
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
    @background = Twitstream::Background.new
    # Start with an empty database for each test.
    redis = Twitstream::Store::RedisBase.new
    redis.flushdb
    @background.twitter_store.store(@user_ids[0], @twitter_ids[0])
    @background.twitter_store.store(@user_ids[1], @twitter_ids[1])
  end

  it "starts" do
    expect(@background.streamer).to receive(:start).with(@twitter_ids)
    @background.start
  end

  it "polls registrations" do
    uuid = ::UUID.generate
    twitter_id = 12345
    redis = double('redis')
    blpop = double('redis_blpop')

    expect(@background).to receive(:em_redis).and_return(redis)
    expect(redis).to receive(:blpop).with('twitstream:new', 0).and_return(blpop)
    expect(blpop).to receive(:callback).and_yield([], uuid)
    expect(@background.twitter_store).to receive(:get_twitter_id).with(uuid).and_return(twitter_id)
    expect(@background.streamer).to receive(:add_user).with(twitter_id)

    # TODO: Test the EventMachine.next_tick{poll_registrations} bit
    @background.poll_registrations
  end

  it "polls deregistrations" do
    uuid = ::UUID.generate
    twitter_id = 12345
    redis = double('redis')
    blpop = double('redis_blpop')

    expect(@background).to receive(:em_redis).and_return(redis)
    expect(redis).to receive(:blpop).with('twitstream:old', 0).and_return(blpop)
    expect(blpop).to receive(:callback).and_yield([], uuid)
    expect(@background.twitter_store).to receive(:get_twitter_id).with(uuid).and_return(twitter_id)
    expect(@background.streamer).to receive(:remove_user).with(twitter_id)
    expect(@background.twitter_store).to receive(:del_by_id).with(uuid)

    # TODO: Test the EventMachine.next_tick{poll_registrations} bit
    @background.poll_deregistrations
  end

  it "starts emitting events" do
    expect(@background.bergcloud).to receive(:start_emitting)
    @background.start_emitting_events
  end

  it "has a redis" do
    expect(@background.em_redis).to be_an_instance_of(EventMachine::Hiredis::Client)
  end

end

