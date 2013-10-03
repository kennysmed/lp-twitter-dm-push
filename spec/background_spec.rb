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
    expect(client_control).to receive(:add_user).exactly(extras.length).times.and_return(extras.shift)

    expectation = EventMachine.should_receive(:add_periodic_timer)
    (0..extras.length).each { expectation.and_yield }

    @background.add_first_users_to_stream(client, twitter_ids)
  end

  describe "deals with a direct message" do
    before :all do
      @dm_to_user = {
        :for_user => 10765432100123456789,
        :message => {
          :direct_message => {
            :id => 9876543210,
            :recipient_id => 10765432100123456789,
            :text => "My direct message text"
          }
        }
      }
      @dm_from_user = {
        :for_user => 10765432100123456789,
        :message => {
          :direct_message => {
            :id => 9876543210,
            :recipient_id => 1234567,
            :text => "My direct message text"
          }
        }
      }
    end

    it "to the user" do
      client = double('client')
      expect(client).to receive(:sitestream).and_yield(@dm_to_user)
      expect(@background.bergcloud).to receive(:direct_message).with(
                Twitter::DirectMessage.new(@dm_to_user[:message][:direct_message]))

      @background.add_first_users_to_stream(client, @twitter_ids)
    end

    it "from the user" do
      client = double('client')
      expect(client).to receive(:sitestream).and_yield(@dm_from_user)
      expect(@background.bergcloud).not_to receive(:direct_message)

      @background.add_first_users_to_stream(client, @twitter_ids)
    end
  end

  it "creates a new Twitter client" do
    expect(@background.new_client).to be_an_instance_of(::TweetStream::Client)
  end

  it "polls registrations" do
    uuid = ::UUID.generate
    twitter_id = 12345
    redis = double('redis')
    blpop = double('redis_blpop')

    expect(@background).to receive(:em_redis).and_return(redis)
    expect(redis).to receive(:blpop).with('ahola:new', 0).and_return(blpop)
    expect(blpop).to receive(:callback).and_yield([], uuid)
    expect(@background.twitter_store).to receive(:get_twitter_id).with(uuid).and_return(twitter_id)
    expect(@background).to receive(:add_user).with(twitter_id)

    # TODO: Test the EventMachine.next_tick{poll_registrations} bit
    @background.poll_registrations
  end

  it "polls deregistrations" do
    uuid = ::UUID.generate
    redis = double('redis')
    blpop = double('redis_blpop')

    expect(@background).to receive(:em_redis).and_return(redis)
    expect(redis).to receive(:blpop).with('ahola:old', 0).and_return(blpop)
    expect(blpop).to receive(:callback).and_yield([], uuid)
    expect(@background.twitter_store).to receive(:get_twitter_id).with(uuid).and_return(twitter_id)
    expect(@background).to receive(:remove_user).with(twitter_id)
    expect(@background.twitter_store).to receive(:del_by_id).with(uuid)


    # TODO: Test the EventMachine.next_tick{poll_registrations} bit
    @background.poll_deregistrations
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

