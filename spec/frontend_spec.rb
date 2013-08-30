require 'spec_helper'
require 'timecop'
require 'ahola/frontend'

describe "Frontend" do
  def app
    Ahola::Frontend
  end

  describe "getting /" do
    before :each do
      get '/'
    end
    it "returns 200" do
      last_response.status.should == 200
    end
    it "contains the correct content" do
      last_response.body.should include(format_title)
    end
  end

  describe "favicon" do
    it "returns 410" do
      get '/favicon.ico'
      last_response.status.should == 410
    end
  end

  describe "getting /sample/" do
    before :each do
      Timecop.freeze(Time.local(2013, 8, 30, 15, 30, 00))
      get '/sample/'
    end
    after :each do
      Timecop.return
    end

    it "shows correct time" do
      last_response.body.should include(Time.now.strftime('<strong>%l:%M %p</strong>, %-d %B %Y'))
    end

    it "shows correct avatar" do
      last_response.body.should include('https://si0.twimg.com/profile_images/1167616130/james_200208_300x300_normal.jpg')
    end

    it "has the correct ETag" do
      last_response.headers['ETag'].should eq('"7b7d7d461d5afc0d4622b2a056fd87c7"')
    end
  end

  describe "Helpers" do
    describe "format_title" do
      it "returns the correct title" do
        format_title.should eq("Little Printer Twitter Direct Message Publication")
      end
    end
  end
end


