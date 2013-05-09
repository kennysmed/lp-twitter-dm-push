require 'json'
require 'uuid'
require 'uri'
require 'sinatra/base'
require 'ahola/twitter'
require 'ahola/store'


module Ahola
  class Frontend < Sinatra::Base
    set :bind, '0.0.0.0'
    set :public_folder, 'public'

    token_store = Ahola::Store::Token.new
    subscription_store = Ahola::Store::Subscription.new
    registrations = Ahola::Store::Registration.new
    twitter_data = Ahola::Store::TwitterData.new
    # events = Kachina::Store::Event.new


    get '/' do
      "Ahola"
    end


    get '/favicon.ico' do
      status 410
    end


    # The user has come here from the Remote, to authenticate our publication's
    # use of their Twitter account.
    get '/configure/' do
      # We assign an id for each user.
      id = UUID.generate
      consumer = Ahola::Twitter.consumer
      query = URI.encode_www_form(:id => id,
                                  :return_url => params[:return_url],
                                  :error_url => params[:error_url])
      callback_url = url('/authorised/') + "?" + query
      puts "CALLBACK: #{callback_url}"
      begin
        request_token = consumer.get_request_token(
                                              :oauth_callback => callback_url)
      rescue OAuth::Unauthorized
        puts "UNAUTH: #{params[:error_url]}"
        redirect params[:error_url], 401
      end
      token_store.store(:request_token, id, request_token)
      redirect request_token.authorize_url(:oauth_callback => callback_url)
    end


    # Where the user is returned to after authenticating our app at Twitter.
    get '/authorised/' do
      if params[:denied]
        # TODO: We should return to Remote somehow...?
        return 500, "You chose not to authorise with Twitter. No problem, but we don't handle this very well at the moment, sorry."
      end

      id = params[:id]
      consumer = Ahola::Twitter.consumer

      begin
        if request_token = token_store.get(:request_token, id, consumer)
          access_token = request_token.get_access_token(
                                    :oauth_verifier => params[:oauth_verifier])
          token_store.store(:access_token, id, access_token)
          twitter_data.store(id,
                             access_token.params['user_id'],
                             access_token.params['screen_name'])
          token_store.del(:request_token, id)
          query = URI.encode_www_form("config[id]" => id)
          # All good, send the user back to Remote.
          redirect params[:return_url] + "?" + query
        else
          redirect params[:error_url]
        end
      rescue OAuth::Unauthorized
        redirect params[:error_url], 401
      end
    end


    # For Push publications the Remote sends a request here when the user
    # subscribes, with the subscription ID and the endpoint that we send
    # content to to be printed.
    post '/validate_config/' do
      subscription_id = params[:subscription_id]
      endpoint = params[:endpoint]
      config = JSON.parse(params[:config])
      id = config['id']
      content_type :json

      if access_token = token_store.get(
                                    :access_token, id, Ahola::Twitter.consumer)
        subscription_store.store(id, subscription_id, endpoint)
        registrations.add(id)
        {:valid => true}.to_json
      else
        {:valid => false}.to_json
      end
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
