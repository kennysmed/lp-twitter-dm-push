require 'spec_helper'
require 'ahola/store'
require 'ahola/twitter'
require 'twitter'
require 'uuid'


describe "Store" do
  before :all do
    @direct_messages = [
      Twitter::DirectMessage.new(
        :id => 1825786345,
        :text => "Here's my test direct message",
        :created_at => "Mon Jul 16 12:59:01 +0000 2013",
        :recipient => {
          :id => 6253282,
          :name => "Mr Receiver",
          :profile_image_url => "http://a3.twimg.com/profile_images/689684365/api_normal.png",
          :screen_name => "mrreceiver",
        },
        :sender => {
          :id => 18253293,
          :name => "Ms Sender",
          :profile_image_url => "http://a3.twimg.com/profile_images/919684372/api_normal.png",
          :screen_name => "mssender",
        }
      ),
      Twitter::DirectMessage.new(
        :id => 98765432109,
        :text => "Another direct message is here",
        :created_at => "Mon Jul 17 18:19:22 +0000 2013",
        :recipient => {
          :id => 6253282,
          :name => "Mr Receiver",
          :profile_image_url => "http://a3.twimg.com/profile_images/689684365/api_normal.png",
          :screen_name => "mrreceiver",
        },
        :sender => {
          :id => 1234567890,
          :name => "Mrs Poster",
          :profile_image_url => "http://a3.twimg.com/profile_images/827364819/api_normal.png",
          :screen_name => "mrsposter",
        }
      ),
    ]
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
      @event_store.count(@user_ids[0]).should eq(1)
    end

    it "retrieves and deletes direct messages" do
      @event_store.direct_message!(@user_ids[0], @direct_messages[0])
      @event_store.direct_message!(@user_ids[0], @direct_messages[1])
      messages = @event_store.get_and_reset_messages!(@user_ids[0])
      messages.length.should eq(2)
      messages[0][:sender][:name].should eq('Ms Sender')
      messages[1][:text].should eq("Another direct message is here")
      @event_store.count(@user_ids[0]).should eq(0)
    end

    it "returns all the keys" do
      @event_store.direct_message!(@user_ids[0], @direct_messages[0])
      @event_store.direct_message!(@user_ids[1], @direct_messages[1])
      ids = @event_store.all
      ids.length.should eq(2)
      ids.should include(@user_ids[0])
      ids.should include(@user_ids[1])
    end

    it "returns all the events" do
      @event_store.direct_message!(@user_ids[0], @direct_messages[0])
      @event_store.direct_message!(@user_ids[1], @direct_messages[1])
      count = 0
      @event_store.each do |dm|
        @user_ids.should include(dm)
        count += 1
      end
      count.should eq(2)
    end

    it "counts the events" do
      @event_store.direct_message!(@user_ids[0], @direct_messages[0])
      @event_store.direct_message!(@user_ids[0], @direct_messages[1])
      @event_store.count(@user_ids[0]).should eq(2)
    end
  end

  describe "Registration" do
    before :each do
      @registration_store = Ahola::Store::Registration.new
    end

    it "adds to 'registrations' and 'new'" do
      @registration_store.add(@user_ids[0])
      @registration_store.redis.sismember('registrations', @user_ids[0]).should eq(true)
      @registration_store.redis.lpop('new').should eq(@user_ids[0])
    end

    it "loops through IDs" do
      @registration_store.add(@user_ids[0])
      @registration_store.add(@user_ids[1])
      @registration_store.each do |reg|
        @user_ids.should include(reg)
      end
    end

    it "returns all IDs" do
      @registration_store.add(@user_ids[0])
      @registration_store.add(@user_ids[1])
      all = @registration_store.all
      all.length.should eq(2)
      all.should include(@user_ids[0])
      all.should include(@user_ids[1])
    end

    it "deletes an ID" do
      @registration_store.add(@user_ids[0])
      @registration_store.all.length.should eq(1)
      @registration_store.del(@user_ids[0])
      @registration_store.all.length.should eq(0)
    end

    it "can tell when it contains a specific ID" do
      @registration_store.add(@user_ids[0])
      @registration_store.contains(@user_ids[0]).should eq(true)
    end

    it "can tell when it doesn't contain a specific ID" do
      @registration_store.add(@user_ids[0])
      @registration_store.contains(@user_ids[1]).should eq(false)
    end

    it "resets the 'new' list of IDs" do
      @registration_store.add(@user_ids[0])
      @registration_store.fresh!
      @registration_store.redis.lpop('new').should eq(nil)
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
      subs_data[0].should eq(@subscription_id)
      subs_data[1].should eq(@endpoint)
    end

    it "gets subscription data" do
      @subscription_store.store(@user_ids[0], @subscription_id, @endpoint)
      subs_data = @subscription_store.get(@user_ids[0])
      subs_data[0].should eq(@subscription_id)
      subs_data[1].should eq(@endpoint)
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
        token_data[0].should eq(@oauth_token)
        token_data[1].should eq(@oauth_token_secret)
      end

      it "deletes details" do
        @token_store.del(:request_token, @user_ids[0])
        token_data = @token_store.redis.hget(:request_token, @user_ids[0])
        token_data.should eq(nil)
      end

      it "gets credentials" do
        token_data = @token_store.get_credentials(:request_token, @user_ids[0])
        token_data[0].should eq(@oauth_token)
        token_data[1].should eq(@oauth_token_secret)
      end

      it "gets a token object" do
        token = @token_store.get(:request_token, @user_ids[0], Ahola::Twitter.consumer)
        token.should be_an_instance_of(OAuth::RequestToken)
        token.token.should eq(@oauth_token)
        token.secret.should eq(@oauth_token_secret)
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
        token_data[0].should eq(@oauth_token)
        token_data[1].should eq(@oauth_token_secret)
      end

      it "deletes details" do
        @token_store.store(:access_token, @user_ids[0],
                           AccessToken.new(@oauth_token, @oauth_token_secret))
        @token_store.del(:access_token, @user_ids[0])
        token_data = @token_store.redis.hget(:access_token, @user_ids[0])
        token_data.should eq(nil)
      end

      it "gets credentials" do
        token_data = @token_store.get_credentials(:access_token, @user_ids[0])
        token_data[0].should eq(@oauth_token)
        token_data[1].should eq(@oauth_token_secret)
      end

      it "gets a token object" do
        token = @token_store.get(:access_token, @user_ids[0], Ahola::Twitter.consumer)
        token.should be_an_instance_of(OAuth::AccessToken)
        token.token.should eq(@oauth_token)
        token.secret.should eq(@oauth_token_secret)
      end
    end
  end
  

end
