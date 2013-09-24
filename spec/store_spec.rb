require 'spec_helper'
require 'ahola/store'
require 'ahola/twitter'
require 'twitter'
require 'uuid'


describe "Store" do
  before :all do
    # From spec_helpers.
    @direct_messages = direct_messages
  end

  before :each do
    # Start with an empty database for each test.
    redis = Ahola::Store::RedisBase.new
    redis.flushdb
    @user_ids = [::UUID.generate, ::UUID.generate]
  end

  describe "Event" do
    before :each do
      @event_store = Ahola::Store::Event.new
    end

    it "stores a direct message" do
      @event_store.direct_message!(@user_ids[0], @direct_messages[0])
      expect(@event_store.count(@user_ids[0])).to eq(1)
    end

    it "retrieves and deletes direct messages" do
      @event_store.direct_message!(@user_ids[0], @direct_messages[0])
      @event_store.direct_message!(@user_ids[0], @direct_messages[1])
      messages = @event_store.get_and_reset_messages!(@user_ids[0])
      expect(messages.length).to eq(2)
      expect(messages[0][:sender][:name]).to eq('Ms Sender')
      expect(messages[1][:text]).to eq("Another direct message is here")
      expect(@event_store.count(@user_ids[0])).to eq(0)
    end

    it "returns all the keys" do
      @event_store.direct_message!(@user_ids[0], @direct_messages[0])
      @event_store.direct_message!(@user_ids[1], @direct_messages[1])
      ids = @event_store.all
      expect(ids.length).to eq(2)
      expect(ids).to include(@user_ids[0])
      expect(ids).to include(@user_ids[1])
    end

    it "returns all the events" do
      @event_store.direct_message!(@user_ids[0], @direct_messages[0])
      @event_store.direct_message!(@user_ids[1], @direct_messages[1])
      count = 0
      @event_store.each do |dm|
        expect(@user_ids).to include(dm)
        count += 1
      end
      expect(count).to eq(2)
    end

    it "counts the events" do
      @event_store.direct_message!(@user_ids[0], @direct_messages[0])
      @event_store.direct_message!(@user_ids[0], @direct_messages[1])
      expect(@event_store.count(@user_ids[0])).to eq(2)
    end
  end

  describe "Registration" do
    before :each do
      @registration_store = Ahola::Store::Registration.new
    end

    it "adds to 'registrations' and 'new'" do
      @registration_store.add(@user_ids[0])
      expect(@registration_store.redis.sismember('registrations', @user_ids[0])).to eq(true)
      expect(@registration_store.redis.lpop('new')).to eq(@user_ids[0])
    end

    it "loops through IDs" do
      @registration_store.add(@user_ids[0])
      @registration_store.add(@user_ids[1])
      @registration_store.each do |reg|
        expect(@user_ids).to include(reg)
      end
    end

    it "returns all IDs" do
      @registration_store.add(@user_ids[0])
      @registration_store.add(@user_ids[1])
      all = @registration_store.all
      expect(all.length).to eq(2)
      expect(all).to include(@user_ids[0])
      expect(all).to include(@user_ids[1])
    end

    it "deletes an ID" do
      @registration_store.add(@user_ids[0])
      expect(@registration_store.all.length).to eq(1)
      @registration_store.del(@user_ids[0])
      expect(@registration_store.all.length).to eq(0)
    end

    it "can tell when it contains a specific ID" do
      @registration_store.add(@user_ids[0])
      expect(@registration_store.contains(@user_ids[0])).to eq(true)
    end

    it "can tell when it doesn't contain a specific ID" do
      @registration_store.add(@user_ids[0])
      expect(@registration_store.contains(@user_ids[1])).to eq(false)
    end

    it "resets the 'new' list of IDs" do
      @registration_store.add(@user_ids[0])
      @registration_store.fresh!
      expect(@registration_store.redis.lpop('new')).to eq(nil)
    end
  end

  describe "Subscription" do
    before :each do
      @subscription_store = Ahola::Store::Subscription.new
      @subscription_id = '2ca7287d935ae2a6a562a3a17bdddcbe81e79d43'
      @endpoint = "http://api.bergcloud.com/v1/subscriptions/2ca7287d935ae2a6a562a3a17bdddcbe81e79d43/publish"
    end

    it "stores subscription data" do
      @subscription_store.store(@user_ids[0], @subscription_id, @endpoint)
      subs_data = Marshal.load(@subscription_store.redis.hget(:subscriptions, @user_ids[0]))
      expect(subs_data[0]).to eq(@subscription_id)
      expect(subs_data[1]).to eq(@endpoint)
    end

    it "gets subscription data" do
      @subscription_store.store(@user_ids[0], @subscription_id, @endpoint)
      subs_data = @subscription_store.get(@user_ids[0])
      expect(subs_data[0]).to eq(@subscription_id)
      expect(subs_data[1]).to eq(@endpoint)
    end
  end

  describe "Token" do
    # This does assume that Ahola::Twitter works OK.

    before :each do
      @token_store = Ahola::Store::Token.new
      @oauth_token = 'NPcudxy0yU5T3tBzho7iCotZ3cnetKwcTIRlX0iwRl0'
      @oauth_token_secret = 'veNRnAWe6inFuo8o2u8SLLZLjolYDmDP7SzL0YfYI'
    end

    describe "for request token" do
      before :all do
        # Very dummy object, rather than dealing with OAuth Consumers etc.
        RequestToken = Struct.new(:token, :secret)
      end

      before :each do
        @token_store.store(:request_token, @user_ids[0],
                           RequestToken.new(@oauth_token, @oauth_token_secret))
      end

      it "stores details" do
        token_data = Marshal.load(
                           @token_store.redis.hget(:request_token, @user_ids[0]))
        expect(token_data[0]).to eq(@oauth_token)
        expect(token_data[1]).to eq(@oauth_token_secret)
      end

      it "deletes details" do
        @token_store.del(:request_token, @user_ids[0])
        token_data = @token_store.redis.hget(:request_token, @user_ids[0])
        expect(token_data).to eq(nil)
      end

      it "gets credentials" do
        token_data = @token_store.get_credentials(:request_token, @user_ids[0])
        expect(token_data[0]).to eq(@oauth_token)
        expect(token_data[1]).to eq(@oauth_token_secret)
      end

      it "gets a token object" do
        token = @token_store.get(:request_token, @user_ids[0], Ahola::Twitter.consumer)
        expect(token).to be_an_instance_of(OAuth::RequestToken)
        expect(token.token).to eq(@oauth_token)
        expect(token.secret).to eq(@oauth_token_secret)
      end
    end

    describe "for access token" do
      before :all do
        # Very dummy object, rather than dealing with OAuth Consumers etc.
        AccessToken = Struct.new(:token, :secret)
      end

      before :each do
        @token_store.store(:access_token, @user_ids[0],
                           AccessToken.new(@oauth_token, @oauth_token_secret))
      end

      it "stores details" do
        token_data = Marshal.load(
                           @token_store.redis.hget(:access_token, @user_ids[0]))
        expect(token_data[0]).to eq(@oauth_token)
        expect(token_data[1]).to eq(@oauth_token_secret)
      end

      it "deletes details" do
        @token_store.store(:access_token, @user_ids[0],
                           AccessToken.new(@oauth_token, @oauth_token_secret))
        @token_store.del(:access_token, @user_ids[0])
        token_data = @token_store.redis.hget(:access_token, @user_ids[0])
        expect(token_data).to eq(nil)
      end

      it "gets credentials" do
        token_data = @token_store.get_credentials(:access_token, @user_ids[0])
        expect(token_data[0]).to eq(@oauth_token)
        expect(token_data[1]).to eq(@oauth_token_secret)
      end

      it "gets a token object" do
        token = @token_store.get(:access_token, @user_ids[0], Ahola::Twitter.consumer)
        expect(token).to be_an_instance_of(OAuth::AccessToken)
        expect(token.token).to eq(@oauth_token)
        expect(token.secret).to eq(@oauth_token_secret)
      end
    end
  end

  describe "Twitter" do

    before :each do
      @twitter_store = Ahola::Store::Twitter.new
    end

    it "stores data" do
      @twitter_store.store(@user_ids[0], 10765432100123456789, 'philgyford')
      user_data = Marshal.load(@twitter_store.redis.hget(:twitter, @user_ids[0]))
      expect(user_data[0]).to eq(10765432100123456789)
      expect(user_data[1]).to eq('philgyford')
    end
    
    it "retrieves data" do
      @twitter_store.redis.hset(:twitter, @user_ids[0], Marshal.dump([10765432100123456789, 'philgyford']))
      user_data = @twitter_store.get(@user_ids[0])
      expect(user_data[0]).to eq(10765432100123456789)
      expect(user_data[1]).to eq('philgyford')
    end
  end
  

end
