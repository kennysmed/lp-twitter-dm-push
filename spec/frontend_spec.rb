require 'spec_helper'
require 'timecop'
require 'twitterpush/frontend'
require 'uuid'

describe "Frontend" do
  def app
    TwitterPush::Frontend
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
      expect(last_response.status).to eq(200)
    end
    it "contains the correct content" do
      expect(last_response.body).to include(format_title)
    end
  end


  describe "favicon" do
    it "returns 410" do
      get '/favicon.ico'
      expect(last_response.status).to eq(410)
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

    it "returns 200" do
      get "/sample/"
      expect(last_response.status).to eq(200)
    end

    it "shows correct time" do
      expect(last_response.body).to include(Time.now.strftime('<strong>%l:%M %p</strong>, %-d %B %Y'))
    end

    it "contains correct content" do
      expect(last_response.body).to include("From:</span>\n        <span class=\"person-name\">Phil Gyford")
      expect(last_response.body).to include("How long are you in town for?")
    end

    it "shows correct avatar" do
      expect(last_response.body).to include('https://si0.twimg.com/profile_images/1167616130/james_200208_300x300_normal.jpg')
    end

    it "has the correct ETag" do
      expect(last_response.headers['ETag']).to eq('"7b7d7d461d5afc0d4622b2a056fd87c7"')
    end
  end


  describe "getting /configure/" do
    before :all do
      @configure_url = "/configure/?id=#{@user_id}&return_url=#{@return_url}&error_url=#{@error_url}"
    end

    # TODO
    # Not really sure how best to test all these with test Twitter OAuth
    # credentials.

    #it "redirects to the correct domain" do
      #get @configure_url
      #expect(last_response.headers['Location']).to start_with('https://api.twitter.com/oauth/authorize')
    #end

    #describe "'s redirect query" do
      #before :all do
        #get @configure_url
        #p last_response.headers
        #redirect_uri = ::URI.parse(last_response.headers['Location'])
        #@redirect_query = ::CGI.parse(redirect_uri.query)
      #end

      #it "includes an oauth_token" do
        #expect(@redirect_query).to have_key('oauth_token')
      #end
    #end

    #describe "'s callback query" do
      #before :all do
        #get @configure_url
        #redirect_uri = ::URI.parse(last_response.headers['Location'])
        #@redirect_query = ::CGI.parse(redirect_uri.query)
        #callback_uri = ::URI.parse(@redirect_query['oauth_callback'][0])
        #@callback_query = ::CGI.parse(callback_uri.query)
      #end

      #it "includes a user_id" do
        #expect(@callback_query).to have_key('id')
      #end

      #it "includes a user_id of the correct length" do
        #expect(@callback_query['id'][0].length).to eq(36)
      #end

      #it "includes a return_url" do
        #expect(@callback_query).to have_key('return_url')
      #end

      #it "includes the correct return_url" do
        #expect(@callback_query['return_url'][0]).to eq @return_url
      #end

      #it "includes a error_url" do
        #expect(@callback_query).to have_key('error_url')
      #end

      #it "includes the correct error_url" do
        #expect(@callback_query['error_url'][0]).to eq @error_url
      #end
    #end

    it "stores the request token" do
      ::UUID.stub(:generate).and_return(@user_id)
      consumer = TwitterPush::Twitter.consumer
      token_store = TwitterPush::Store::Token.new
      token_store.redis.hset(:request_token, @user_id, Marshal.dump(['testtoken', 'testsecret']))
      expect(token_store.get(:request_token, @user_id, consumer)).to be_an_instance_of(OAuth::RequestToken)
    end

    #it "requires valid Twitter API credentials" do
      #TwitterPush::Twitter.stub(:consumer).and_return(OAuth::Consumer.new(
                            #'bad', 'creds', :site => 'https://api.twitter.com'))
      #get @configure_url
      #expect(last_response.headers['Location']).to eq(@error_url) 
    #end

    it "requires a return_url" do
      get "/configure/?error_url=#{@error_url}"
      expect(last_response.status).to eq(400)
    end
    it "requires an error_url" do
      get "/configure/?return_url=#{@return_url}"
      expect(last_response.status).to eq(400)
    end
    it "requires a bergcloud.com return_url" do
      get "/configure/?return_url=http://remote.berglondon.com/publications/145/subscription_configuration_return&error_url=#{@error_url}"
      expect(last_response.status).to eq(403)
    end
    it "requires a bergcloud.com error_url" do
      get "/configure/?return_url=#{@return_url}&error_url=http://remote.berglondon.com/publications/145/subscription_configuration_failure"
      expect(last_response.status).to eq(403)
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
      expect(last_response.headers['Location']).to eq(@error_url)
    end

    # TODO
    # Can't work out how to do this.
    # The access_token fetched in the Frontend method is, of course, always
    # invalid.
    #it "successfully redirects back to remote" do
      #get @authorised_url
      #expect(last_response.headers['Location']).to eq(
            #@return_url + '?' + ::URI.encode_www_form("config[id]" => @user_id))
    #end

    # TODO
    # Can't work out how to do this either.
    #it "deletes the request_token from the store" do
      #consumer = TwitterPush::Twitter.consumer
      #token_store = TwitterPush::Store::Token.new
      #request_token = OAuth::RequestToken.new(consumer, 'mytoken', 'mysecret')
      #token_store.store(:request_token, @user_id, request_token)

      #stub_request(:post, "https://api.twitter.com/oauth/request_token").to_return(:body => "oauth_token=t&oauth_token_secret=s")
      #stub_request(:post, "https://api.twitter.com/oauth/access_token").to_return(:body => "oauth_token=at&oauth_token_secret=as&screen_name=sn")

      #get @authorised_url
      #p "HERE"
      #p token_store.get(:request_token, @user_id, consumer)
    #end
    
    #it "stores twitter data" do
    #end

    it "requires a return_url" do
      get "/authorised/?error_url=#{@error_url}"
      expect(last_response.status).to eq(400)
    end
    it "requires an error_url" do
      get "/authorised/?return_url=#{@return_url}"
      expect(last_response.status).to eq(400)
    end
    it "requires a bergcloud.com return_url" do
      get "/authorised/?return_url=http://remote.berglondon.com/publications/145/subscription_configuration_return&error_url=#{@error_url}"
      expect(last_response.status).to eq(403)
    end
    it "requires a bergcloud.com error_url" do
      get "/authorised/?return_url=#{@return_url}&error_url=http://remote.berglondon.com/publications/145/subscription_configuration_failure"
      expect(last_response.status).to eq(403)
    end
  end


  describe "posting to /validate_config/" do
    before :each do
      @post_args = {
        :subscription_id => '2ca7287d935ae2a6a562a3a17bdddcbe81e79d43',
        :config => {:id => @user_id}.to_json,
        :endpoint => "http://api.bergcloud.com/v1/subscriptions/2ca7287d935ae2a6a562a3a17bdddcbe81e",
      }
      # Store a fake access_token so that things work for @user_id:
      token_store = TwitterPush::Store::Token.new
      token_store.store(:access_token, @user_id, OAuth::RequestToken.new(TwitterPush::Twitter.consumer, 'test_token', 'test_secret'))
    end

    it "returns true with valid data" do
      post "/validate_config/", @post_args
      expect(JSON.parse(last_response.body)['valid']).to be_true
    end

    it "returns false with no subscription_id" do
      @post_args.delete(:subscription_id)
      post "/validate_config/", @post_args
      expect(JSON.parse(last_response.body)['valid']).to be_false
      expect(JSON.parse(last_response.body)['errors'][0]).to eq("No subscription ID supplied")
    end

    it "returns false with invalid endpoint" do
      @post_args[:endpoint] = 'http://www.example.org/an/endpoint'
      post "/validate_config/", @post_args
      expect(JSON.parse(last_response.body)['valid']).to be_false
      expect(JSON.parse(last_response.body)['errors'][0]).to eq("Invalid domain for BERG Cloud API endpoint")
    end

    it "returns false with no endpoint" do
      @post_args.delete(:endpoint)
      post "/validate_config/", @post_args
      expect(JSON.parse(last_response.body)['valid']).to be_false
      expect(JSON.parse(last_response.body)['errors'][0]).to eq("No BERG Cloud API endpoint supplied")
    end

    it "returns false with invalid user_id" do
      @post_args[:config] = {:id => 99}.to_json
      post "/validate_config/", @post_args
      expect(JSON.parse(last_response.body)['valid']).to be_false
      expect(JSON.parse(last_response.body)['errors'][0]).to eq("No Twitter access token found")
    end

    it "returns false with no user_id" do
      @post_args.delete(:config)
      post "/validate_config/", @post_args
      expect(JSON.parse(last_response.body)['valid']).to be_false
      expect(JSON.parse(last_response.body)['errors'][0]).to eq("No ID supplied in config data")
    end

    it "stores a new subscription" do
      post "/validate_config/", @post_args
      subs = TwitterPush::Store::Subscription.new.get(@user_id)
      expect(subs[0]).to eq('2ca7287d935ae2a6a562a3a17bdddcbe81e79d43')
      expect(subs[1]).to eq("http://api.bergcloud.com/v1/subscriptions/2ca7287d935ae2a6a562a3a17bdddcbe81e")
    end

    it "adds a new registration" do
      post "/validate_config/", @post_args
      expect(TwitterPush::Store::Registration.new.contains(@user_id)).to be_true
    end
  end

end


