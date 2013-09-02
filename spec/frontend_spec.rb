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

  describe "getting /configure/" do
    before :all do
      @return_url = 'http://remote.bergcloud.com/publications/145/subscription_configuration_return'
      @error_url = 'http://remote.bergcloud.com/publications/145/subscription_configuration_failure'
      @configure_url = "/configure/?return_url=#{@return_url}&error_url=#{@error_url}"
    end

    it "redirects" do
      get @configure_url
      last_response.status.should == 302
    end

    it "redirects to the correct domain" do
      get @configure_url
      last_response.headers['Location'].should start_with('https://api.twitter.com/oauth/authorize')
    end

    describe "'s redirect query" do
      before :all do
        get @configure_url
        redirect_uri = ::URI.parse(last_response.headers['Location'])
        @redirect_query = ::CGI.parse(redirect_uri.query)
      end

      it "includes an oauth_token" do
        @redirect_query.should have_key('oauth_token')
      end
    end

    describe "'s callback query" do
      before :all do
        get @configure_url
        redirect_uri = ::URI.parse(last_response.headers['Location'])
        @redirect_query = ::CGI.parse(redirect_uri.query)
        callback_uri = ::URI.parse(@redirect_query['oauth_callback'][0])
        @callback_query = ::CGI.parse(callback_uri.query)
      end

      it "includes a user_id" do
        @callback_query.should have_key('id')
      end

      it "includes a user_id of the correct length" do
        @callback_query['id'][0].length.should eq(36)
      end

      it "includes a return_url" do
        @callback_query.should have_key('return_url')
      end

      it "includes the correct return_url" do
        @callback_query['return_url'][0].should eq @return_url
      end

      it "includes a error_url" do
        @callback_query.should have_key('error_url')
      end

      it "includes the correct error_url" do
        @callback_query['error_url'][0].should eq @error_url
      end

    end


    it "requires valid Twitter API credentials" do
      Ahola::Twitter.stub(:consumer).and_return(OAuth::Consumer.new(
                            'bad', 'creds', :site => 'https://api.twitter.com'))
      get @configure_url
      last_response.headers['Location'].should eq(@error_url) 
    end

    it "requires a return_url" do
      get '/configure/?error_url=http://remote.bergcloud.com/publications/145/subscription_configuration_failure'
      last_response.status.should == 400
    end
    it "requires an error_url" do
      get '/configure/?return_url=http://remote.bergcloud.com/publications/145/subscription_configuration_return'
      last_response.status.should == 400
    end
    it "requires a bergcloud.com return_url" do
      get '/configure/?return_url=http://remote.berglondon.com/publications/145/subscription_configuration_return&error_url=http://remote.bergcloud.com/publications/145/subscription_configuration_failure'
      last_response.status.should == 403
    end
    it "requires a bergcloud.com error_url" do
      get '/configure/?return_url=http://remote.bergcloud.com/publications/145/subscription_configuration_return&error_url=http://remote.berglondon.com/publications/145/subscription_configuration_failure'
      last_response.status.should == 403
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


