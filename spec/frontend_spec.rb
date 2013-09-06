require 'spec_helper'
require 'timecop'
require 'ahola/frontend'
require 'uuid'

describe "Frontend" do
  def app
    Ahola::Frontend
  end

  before :all do
    @return_url = 'http://remote.bergcloud.com/publications/145/subscription_configuration_return'
    @error_url = 'http://remote.bergcloud.com/publications/145/subscription_configuration_failure'
    @user_id = 'be8b7db0-f936-0130-30c2-10ddb1a61923'
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
      @configure_url = "/configure/?id=#{@user_id}&return_url=#{@return_url}&error_url=#{@error_url}"
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

    it "stores the request token" do
      ::UUID.stub(:generate).and_return(@user_id)
      get @configure_url
      
      consumer = Ahola::Twitter.consumer
      token_store = Ahola::Store::Token.new
      token_store.get(:request_token, @user_id, consumer).should be_an_instance_of(OAuth::RequestToken)
    end

    it "requires valid Twitter API credentials" do
      Ahola::Twitter.stub(:consumer).and_return(OAuth::Consumer.new(
                            'bad', 'creds', :site => 'https://api.twitter.com'))
      get @configure_url
      last_response.headers['Location'].should eq(@error_url) 
    end

    it "requires a return_url" do
      get "/configure/?error_url=#{@error_url}"
      last_response.status.should == 400
    end
    it "requires an error_url" do
      get "/configure/?return_url=#{@return_url}"
      last_response.status.should == 400
    end
    it "requires a bergcloud.com return_url" do
      get "/configure/?return_url=http://remote.berglondon.com/publications/145/subscription_configuration_return&error_url=#{@error_url}"
      last_response.status.should == 403
    end
    it "requires a bergcloud.com error_url" do
      get "/configure/?return_url=#{@return_url}&error_url=http://remote.berglondon.com/publications/145/subscription_configuration_failure"
      last_response.status.should == 403
    end
  end

  describe "getting /authorised/" do
    before :all do
      @oauth_token = 'XxKva554iTqVnUmtobGTLLcAZJ1F7SS55KdUnk1aQ'
      @oauth_verifier = 'dfqlSsqPdkwdMwVoe0wPtFvLzSWcRg4PM2rkKFfM48'
      @authorised_url = "/authorised/?return_url=%s&error_url=%s&id=%s&oauth_token=%s&oauth_verifier=%s" % [
                @return_url, @error_url, @user_id, @oauth_token, @oauth_verifier]
    end

    it "redirects to the error_url if authentication was denied" do
      get "#{@authorised_url}&denied=tgoKUl1sxRxWT0EvAtqAWf4oQ03fKcdHwLnNXm4PY"
      last_response.headers['Location'].should eq(@error_url)
    end

    # TODO
    # Can't work out how to do this.
    # The access_token fetched in the Frontend method is, of course, always
    # invalid.
    #it "successfully redirects back to remote" do
      #get @authorised_url
      #last_response.headers['Location'].should eq(
            #@return_url + '?' + ::URI.encode_www_form("config[id]" => @user_id))
    #end

    # TODO
    # Can't work out how to do this either.
    #it "deletes the request_token from the store" do
      #consumer = Ahola::Twitter.consumer
      #token_store = Ahola::Store::Token.new
      #request_token = OAuth::RequestToken.new(consumer, 'mytoken', 'mysecret')
      #token_store.store(:request_token, @user_id, request_token)

      #stub_request(:post, "https://api.twitter.com/oauth/request_token").to_return(:body => "oauth_token=t&oauth_token_secret=s")
      #stub_request(:post, "https://api.twitter.com/oauth/access_token").to_return(:body => "oauth_token=at&oauth_token_secret=as&screen_name=sn")

      #get @authorised_url
      #p "HERE"
      #p token_store.get(:request_token, @user_id, consumer)
    #end

    it "requires a return_url" do
      get "/authorised/?error_url=#{@error_url}"
      last_response.status.should == 400
    end
    it "requires an error_url" do
      get "/authorised/?return_url=#{@return_url}"
      last_response.status.should == 400
    end
    it "requires a bergcloud.com return_url" do
      get "/authorised/?return_url=http://remote.berglondon.com/publications/145/subscription_configuration_return&error_url=#{@error_url}"
      last_response.status.should == 403
    end
    it "requires a bergcloud.com error_url" do
      get "/authorised/?return_url=#{@return_url}&error_url=http://remote.berglondon.com/publications/145/subscription_configuration_failure"
      last_response.status.should == 403
    end
  end

end


