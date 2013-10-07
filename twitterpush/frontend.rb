require 'json'
require 'uuid'
require 'uri'
require 'sinatra/base'
require 'twitterpush/config'
require 'twitterpush/frontend_helpers'
require 'twitterpush/store'
require 'twitterpush/twitter'


module TwitterPush
  class Frontend < Sinatra::Base
    configure :production, :development do
      enable :logging
    end

    helpers TwitterPush::FrontendHelpers

    set :sessions, true
    set :bind, '0.0.0.0'
    set :public_folder, 'public'

    token_store = TwitterPush::Store::Token.new
    subscription_store = TwitterPush::Store::Subscription.new
    registration_store = TwitterPush::Store::Registration.new
    twitter_store = TwitterPush::Store::Twitter.new
    
    get '/' do
      format_title
    end


    get '/favicon.ico' do
      status 410
    end


    # The user has come here from the Remote, to authenticate our publication's
    # use of their Twitter account.
    get '/configure/' do
      return_url, error_url = check_berg_urls(
                                          params[:return_url], params[:error_url])
    
      id = ::UUID.generate
      consumer = TwitterPush::Twitter.consumer
      query = ::URI.encode_www_form(:id => id,
                                    :return_url => return_url,
                                    :error_url => error_url)
      callback_url = url('/authorised/') + "?" + query
      begin
        request_token = consumer.get_request_token(
                                              :oauth_callback => callback_url)
      rescue ::OAuth::Unauthorized
        redirect error_url
      end
      token_store.store(:request_token, id, request_token)
      redirect request_token.authorize_url(:oauth_callback => callback_url)
    end


    # Where the user is returned to after authenticating our app at Twitter.
    get '/authorised/' do
      return_url, error_url = check_berg_urls(
                                          params[:return_url], params[:error_url])
      if params[:denied]
        redirect error_url
      end

      id = params[:id]
      consumer = TwitterPush::Twitter.consumer

      begin
        if request_token = token_store.get(:request_token, id, consumer)
          access_token = request_token.get_access_token(
                                    :oauth_verifier => params[:oauth_verifier])
          token_store.store(:access_token, id, access_token)
          token_store.del(:request_token, id)
          twitter_store.store(id, access_token.params['user_id'])
          query = ::URI.encode_www_form("config[id]" => id)
          # All good, send the user back to Remote.
          redirect return_url + "?" + query
        else
          redirect error_url
        end
      rescue OAuth::Unauthorized
        redirect error_url
      end
    end


    # For Push publications the Remote sends a request here when the user
    # subscribes, with the subscription ID and the endpoint that we send
    # content to to be printed.
    post '/validate_config/' do
      subscription_id = params[:subscription_id]
      endpoint = params[:endpoint]
      if params[:config]
        config = JSON.parse(params[:config])
        id = config['id']
      end
      content_type :json
      valid = true
      errors = []

      if subscription_id.nil?
        valid = false
        errors << "No subscription ID supplied"
      end
      if endpoint.nil?
        valid = false
        errors << "No BERG Cloud API endpoint supplied"
      elsif ! endpoint[/^https?\:\/\/api\.bergcloud\.com\//]
        valid = false
        errors << "Invalid domain for BERG Cloud API endpoint"
      end
      if id.nil?
        valid = false
        errors << "No ID supplied in config data"
      end

      if access_token = token_store.get(:access_token, id, TwitterPush::Twitter.consumer)
        subscription_store.store(id, subscription_id, endpoint)
        registration_store.add(id)
      else
        valid = false
        errors << "No Twitter access token found"
      end

      if valid
        {:valid => valid}.to_json
      else
        {:valid => valid, :errors => errors}.to_json
      end
    end


    get '/sample/' do
      messages = [{
            :created_at => Time.now(),
            :recipient => {
              :name => 'Tom Coates',
              :profile_image_url => 'https://si0.twimg.com/profile_images/1212320564/Screen_shot_2011-01-10_at_4.24.33_PM_normal.png',
              :screen_name => 'tomcoates',
            },
            :sender => {
              :name => 'Phil Gyford',
              :profile_image_url => 'https://si0.twimg.com/profile_images/1167616130/james_200208_300x300_normal.jpg',
              :screen_name => 'philgyford',
            },
            :text => "How long are you in town for?\nHow about lunch tomorrow?",
          }]

      config = TwitterPush::Config.new

      etag Digest::MD5.hexdigest('sample' + Date.today.strftime('%d%m%Y'))
      content_type 'text/html; charset=utf-8'
      template = ERB.new(File.open('views/publication.erb', 'r').read)
      template.result(binding)
    end

    post '/pretend/:id' do
      # [:mention, :retweet, :new_follower].each do |event|
      #   if count = params[event]
      #     events.event!(params[:id], event, count.to_i)
      #   end
      # end
      # if params[:flourish]
      #   Kachina::BergCloud.new.flourish!(params[:id])
      # end
      # halt 204
    end
  end
end
