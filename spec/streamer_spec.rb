require 'spec_helper'
require 'twitstream/streamer'
require 'em-rspec'

describe "Streamer" do

  before :all do
    @twitter_ids = [10765432100123456789, 12345]
  end

  before :each do
    @streamer = Twitstream::Streamer.new
  end

  it "starts" do
    max_users_per_stream = 1000
    twitter_ids = (0..max_users_per_stream+rand(50)).collect { rand(10000) }
    expect(@streamer).to receive(:start_new_stream).with(twitter_ids.dup[0...max_users_per_stream]).ordered
    expect(@streamer).to receive(:start_new_stream).with(twitter_ids.dup[max_users_per_stream..-1]).ordered
    @streamer.start(twitter_ids)
  end

  it "starts a new stream" do
    expect(@streamer).to receive(:new_client).and_return(Twitstream::Twitter.client)
    expect(@streamer).to receive(:new_client_id).and_return(1)
    expect(@streamer).to receive(:add_first_users_to_stream)
      .with(instance_of(::TweetStream::Client), @twitter_ids)
      .and_return(Twitstream::Twitter.client)
    @streamer.start_new_stream(@twitter_ids.dup)
    expect(@streamer.clients[1]).to be_an_instance_of(::TweetStream::Client)
    expect(@streamer.latest_client_id).to eq(1)
  end

  it "adds first users to a stream" do
    bulk_add_limit = 100
    twitter_ids = (0..bulk_add_limit+rand(50)).collect { rand(10000) }
    extras = twitter_ids[bulk_add_limit..-1]

    client = double('client')
    expect(client).to receive(:sitestream).with(twitter_ids[0...bulk_add_limit])

    client_control = double('client_control')
    expect(client).to receive(:control).exactly(extras.length).times.and_return(client_control)
    expect(client_control).to receive(:add_user).exactly(extras.length).times.and_return(extras.shift)

    expectation = EventMachine.should_receive(:add_periodic_timer)
    (0..extras.length).each { expectation.and_yield }

    @streamer.add_first_users_to_stream(client, twitter_ids)
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
      expect(@streamer.bergcloud).to receive(:direct_message).with(
                Twitter::DirectMessage.new(@dm_to_user[:message][:direct_message]))

      @streamer.add_first_users_to_stream(client, @twitter_ids)
    end

    it "from the user" do
      client = double('client')
      expect(client).to receive(:sitestream).and_yield(@dm_from_user)
      expect(@streamer.bergcloud).not_to receive(:direct_message)

      @streamer.add_first_users_to_stream(client, @twitter_ids)
    end
  end

  it "creates a new Twitter client" do
    expect(@streamer.new_client).to be_an_instance_of(::TweetStream::Client)
  end

  describe "with several clients" do
    before :each do
      @streamer.latest_client_id = 4
      # Add four different clients to @streamer:
      (1..4).each do |id|
        # This ensures they're different objects:
        client = double('client'+id.to_s)
        client_control = double('client_control')
        client.stub(:control).and_return(client_control)
        # A fake method, so we can confirm which client is which.
        client.stub(:id) { id }
        @streamer.clients[id] = client
      end
    end

    it "returns the latest client" do
      expect(@streamer.latest_client.id).to eq(@streamer.latest_client_id) 
    end

    it "adds a user to the latest client" do
      client = @streamer.clients[4]
      expect(@streamer).to receive(:add_user_to_client).with(client, @twitter_ids[0])
      @streamer.add_user(@twitter_ids[0])
    end

    it "adds a user to a supplied client" do
      client = @streamer.clients[4]
      expect(client.control).to receive(:add_user).with(@twitter_ids[0])
      @streamer.add_user_to_client(client, @twitter_ids[0])
    end

    it "creates the next client_id" do
      expect(@streamer.new_client_id).to eq(5)
    end


    describe "and the latest client is full" do
      before :each do
        client = @streamer.clients[4]
        (1..1000).each do |id|
          @streamer.accounts[id] = 4
        end
      end

      it "knows that the latest client is full" do
        expect(@streamer.latest_client_has_room?).to eq(false)
      end

      it "adds a new user to a new stream" do
        expect(@streamer).to receive(:start_new_stream).with([@twitter_ids[0]])
        @streamer.add_user(@twitter_ids[0])
      end
    end

    it "removes a user from the correct client" do
      @streamer.accounts[@twitter_ids[0]] = 3
      expect(@streamer.clients[3]).to receive(:remove_user).with(@twitter_ids[0])
      @streamer.remove_user(@twitter_ids[0])
    end
  end

  describe "with no clients" do
    it "knows that the latest client is full" do
      expect(@streamer.latest_client_has_room?).to eq(true)
    end

    it "adds a new user to a new client" do
      expect(@streamer).to receive(:start_new_stream).with([@twitter_ids[0]])
      @streamer.add_user(@twitter_ids[0])
    end

    it "creates the first client_id" do
      expect(@streamer.new_client_id).to eq(1)
    end
  end
end

