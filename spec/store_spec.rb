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
  end

  describe "Event" do
    before :each do
      @events = Ahola::Store::Event.new
    end

    it "stores a direct message" do
      user_id = ::UUID.generate
      @events.direct_message!(user_id, @direct_messages[0])
      @events.count(user_id).should eq(1)
    end

    it "retrieves and deletes direct messages" do
      user_id = ::UUID.generate
      @events.direct_message!(user_id, @direct_messages[0])
      @events.direct_message!(user_id, @direct_messages[1])
      messages = @events.get_and_reset_events!(user_id)
      messages.length.should eq(2)
      messages[0][:sender][:name].should eq('Ms Sender')
      messages[1][:text].should eq("Another direct message is here")
      @events.count(user_id).should eq(0)
    end

    it "returns all the keys" do
      user_ids = [::UUID.generate, ::UUID.generate, ]
      @events.direct_message!(user_ids[0], @direct_messages[0])
      @events.direct_message!(user_ids[1], @direct_messages[1])
      user_ids = @events.all
      user_ids.length.should eq(2)
      user_ids.should include(user_ids[0])
      user_ids.should include(user_ids[1])
    end

    it "returns all the events" do
      user_ids = [::UUID.generate, ::UUID.generate, ]
      @events.direct_message!(user_ids[0], @direct_messages[0])
      @events.direct_message!(user_ids[1], @direct_messages[1])
      count = 0
      @events.each do |dm|
        user_ids.should include(dm)
        count += 1
      end
      count.should eq(2)
    end

    it "counts the events" do
      user_id = ::UUID.generate
      @events.direct_message!(user_id, @direct_messages[0])
      @events.direct_message!(user_id, @direct_messages[1])
      @events.count(user_id).should eq(2)
    end
  end

  describe "Registration" do

    before :each do
      @registrations = Ahola::Store::Registration.new
    end

    it "adds to 'registrations' and 'new'" do
      user_id = ::UUID.generate
      @registrations.add(user_id)
      @registrations.redis.sismember('registrations', user_id).should eq(true)
      @registrations.redis.lpop('new').should eq(user_id)
    end

    it "can loop through IDs" do
      user_ids = [::UUID.generate, ::UUID.generate]
      @registrations.add(user_ids[0])
      @registrations.add(user_ids[1])
      @registrations.each do |reg|
        user_ids.should include(reg)
      end
    end

    it "returns all IDs" do
      user_ids = [::UUID.generate, ::UUID.generate]
      @registrations.add(user_ids[0])
      @registrations.add(user_ids[1])
      all = @registrations.all
      all.length.should eq(2)
      all.should include(user_ids[0])
      all.should include(user_ids[1])
    end

    it "deletes an ID" do
      user_id = ::UUID.generate
      @registrations.add(user_id)
      @registrations.all.length.should eq(1)
      @registrations.del(user_id)
      @registrations.all.length.should eq(0)
    end

    it "can tell when it contains a specific ID" do
      user_id = ::UUID.generate
      @registrations.add(user_id)
      @registrations.contains(user_id).should eq(true)
    end

    it "can tell when it doesn't contain a specific ID" do
      user_id_1 = ::UUID.generate
      user_id_2 = ::UUID.generate
      @registrations.add(user_id_1)
      @registrations.contains(user_id_2).should eq(false)
    end

    it "can reset the 'new' list of IDs" do
      user_id = ::UUID.generate
      @registrations.add(user_id)
      @registrations.fresh!
      @registrations.redis.lpop('new').should eq(nil)
    end
  end


end
