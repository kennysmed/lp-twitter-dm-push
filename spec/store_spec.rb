require 'spec_helper'
require 'ahola/store'
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
      @events = Ahola::Store::Event.new
    end

    it "stores a direct message" do
      @events.direct_message!(@user_ids[0], @direct_messages[0])
      @events.count(@user_ids[0]).should eq(1)
    end

    it "retrieves and deletes direct messages" do
      @events.direct_message!(@user_ids[0], @direct_messages[0])
      @events.direct_message!(@user_ids[0], @direct_messages[1])
      messages = @events.get_and_reset_events!(@user_ids[0])
      messages.length.should eq(2)
      messages[0][:sender][:name].should eq('Ms Sender')
      messages[1][:text].should eq("Another direct message is here")
      @events.count(@user_ids[0]).should eq(0)
    end

    it "returns all the keys" do
      @events.direct_message!(@user_ids[0], @direct_messages[0])
      @events.direct_message!(@user_ids[1], @direct_messages[1])
      ids = @events.all
      ids.length.should eq(2)
      ids.should include(@user_ids[0])
      ids.should include(@user_ids[1])
    end

    it "returns all the events" do
      @events.direct_message!(@user_ids[0], @direct_messages[0])
      @events.direct_message!(@user_ids[1], @direct_messages[1])
      count = 0
      @events.each do |dm|
        @user_ids.should include(dm)
        count += 1
      end
      count.should eq(2)
    end

    it "counts the events" do
      @events.direct_message!(@user_ids[0], @direct_messages[0])
      @events.direct_message!(@user_ids[0], @direct_messages[1])
      @events.count(@user_ids[0]).should eq(2)
    end
  end

  describe "Registration" do
    before :each do
      @registrations = Ahola::Store::Registration.new
    end

    it "adds to 'registrations' and 'new'" do
      @registrations.add(@user_ids[0])
      @registrations.redis.sismember('registrations', @user_ids[0]).should eq(true)
      @registrations.redis.lpop('new').should eq(@user_ids[0])
    end

    it "can loop through IDs" do
      @registrations.add(@user_ids[0])
      @registrations.add(@user_ids[1])
      @registrations.each do |reg|
        @user_ids.should include(reg)
      end
    end

    it "returns all IDs" do
      @registrations.add(@user_ids[0])
      @registrations.add(@user_ids[1])
      all = @registrations.all
      all.length.should eq(2)
      all.should include(@user_ids[0])
      all.should include(@user_ids[1])
    end

    it "deletes an ID" do
      @registrations.add(@user_ids[0])
      @registrations.all.length.should eq(1)
      @registrations.del(@user_ids[0])
      @registrations.all.length.should eq(0)
    end

    it "can tell when it contains a specific ID" do
      @registrations.add(@user_ids[0])
      @registrations.contains(@user_ids[0]).should eq(true)
    end

    it "can tell when it doesn't contain a specific ID" do
      @registrations.add(@user_ids[0])
      @registrations.contains(@user_ids[1]).should eq(false)
    end

    it "can reset the 'new' list of IDs" do
      @registrations.add(@user_ids[0])
      @registrations.fresh!
      @registrations.redis.lpop('new').should eq(nil)
    end
  end

  describe "Subscription" do
    before :each do
      @subscriptions = Ahola::Store::Subscription.new
      @subscription_id = '2ca7287d935ae2a6a562a3a17bdddcbe81e79d43'
      @endpoint = "http://api.bergcloud.com/v1/subscriptions/2ca7287d935ae2a6a562a3a17bdddcbe81e79d43/publish"
    end

    it "can store subscription data" do
      @subscriptions.store(@user_ids[0], @subscription_id, @endpoint)
      subs_data = Marshal.load(@subscriptions.redis.hget(:subscriptions, @user_ids[0]))
      subs_data[0].should eq(@subscription_id)
      subs_data[1].should eq(@endpoint)
    end

    it "can get subscription data" do
      @subscriptions.store(@user_ids[0], @subscription_id, @endpoint)
      subs_data = @subscriptions.get(@user_ids[0])
      subs_data[0].should eq(@subscription_id)
      subs_data[1].should eq(@endpoint)
    end
  end

end
