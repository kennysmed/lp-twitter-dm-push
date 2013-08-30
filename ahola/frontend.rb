require 'json'
require 'uuid'
require 'uri'
require 'sinatra/base'
require 'ahola/config'
require 'ahola/frontend_helpers'
require 'ahola/store'
require 'ahola/twitter'

module Ahola
  class Frontend < Sinatra::Base
    configure :production, :development do
      enable :logging
    end

    helpers Ahola::FrontendHelpers

    set :sessions, true
    set :bind, '0.0.0.0'
    set :public_folder, 'public'

    token_store = Ahola::Store::Token.new
    subscription_store = Ahola::Store::Subscription.new
    registrations = Ahola::Store::Registration.new
    twitter_data = Ahola::Store::TwitterData.new
    # events = Kachina::Store::Event.new
    
    get '/' do
      format_title
    end


    get '/favicon.ico' do
      status 410
    end


    # The user has come here from the Remote, to authenticate our publication's
    # use of their Twitter account.
    get '/configure/' do
      user_id = UUID.generate
      consumer = Ahola::Twitter.consumer
      query = ::URI.encode_www_form(:id => user_id,
                                  :return_url => params[:return_url],
                                  :error_url => params[:error_url])
      callback_url = url('/authorised/') + "?" + query
      begin
        request_token = consumer.get_request_token(
                                              :oauth_callback => callback_url)
      rescue OAuth::Unauthorized
        redirect params[:error_url]
      end
      token_store.store(:request_token, user_id, request_token)
      redirect request_token.authorize_url(:oauth_callback => callback_url)
    end


    # Where the user is returned to after authenticating our app at Twitter.
    get '/authorised/' do
      if params[:denied]
        # TODO: We should return to Remote somehow...?
        return 500, "You chose not to authorise with Twitter. No problem, but we don't handle this very well at the moment, sorry."
      end

      user_id = params[:id]
      consumer = Ahola::Twitter.consumer

      begin
        if request_token = token_store.get(:request_token, user_id, consumer)
          access_token = request_token.get_access_token(
                                    :oauth_verifier => params[:oauth_verifier])
          token_store.store(:access_token, user_id, access_token)
          twitter_data.store(user_id,
                             access_token.params['user_id'],
                             access_token.params['screen_name'])
          token_store.del(:request_token, user_id)
          query = ::URI.encode_www_form("config[id]" => user_id)
          # All good, send the user back to Remote.
          redirect params[:return_url] + "?" + query
        else
          redirect params[:error_url]
        end
      rescue OAuth::Unauthorized
        redirect params[:error_url]
      end
    end


    # For Push publications the Remote sends a request here when the user
    # subscribes, with the subscription ID and the endpoint that we send
    # content to to be printed.
    post '/validate_config/' do
      subscription_id = params[:subscription_id]
      endpoint = params[:endpoint]
      config = JSON.parse(params[:config])
      user_id = config['id']
      content_type :json

      if access_token = token_store.get(
                                  :access_token, user_id, Ahola::Twitter.consumer)
        subscription_store.store(user_id, subscription_id, endpoint)
        registrations.add(user_id)
        {:valid => true}.to_json
      else
        {:valid => false}.to_json
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

      config = Ahola::Config.new

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
