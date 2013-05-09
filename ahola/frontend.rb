require 'json'
require 'uuid'
require 'uri'
require 'sinatra/base'
# require 'kachina/twitter'
# require 'kachina/store'


module Ahola
  class Frontend < Sinatra::Base
    set :bind, '0.0.0.0'
    set :public_folder, 'public'

    # token_store = Kachina::Store::Token.new
    # subscription_store = Kachina::Store::Subscription.new
    # registrations = Kachina::Store::Registration.new
    # twitter_data = Kachina::Store::TwitterData.new
    # events = Kachina::Store::Event.new


    get '/' do
      "Ahola"
    end


    get '/favicon.ico' do
      status 410
    end


    get '/configure/' do
      # id = UUID.generate
      # consumer = Kachina::Twitter.consumer
      # query = URI.encode_www_form(:id => id,
      #   :return_url => params[:return_url],
      #   :error_url => params[:error_url])
      # callback_url = url('/authorised/') + "?" + query
      # request_token = consumer.get_request_token(:oauth_callback => callback_url)
      # query = URI.encode_www_form(:id => id,
      #   :return_url => params[:return_url],
      #   :error_url => params[:error_url])
      # token_store.store(:request_token, id, request_token)
      # redirect request_token.authorize_url(:oauth_callback => callback_url)
    end


    get '/authorised/' do
      # id = params[:id]
      # consumer = Kachina::Twitter.consumer

      # begin
      #   if request_token = token_store.get(:request_token, id, consumer)
      #     access_token = request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])
      #     token_store.store(:access_token, id, access_token)
      #     twitter_data.store(id, access_token.params['user_id'], access_token.params['screen_name'])
      #     token_store.del(:request_token, id)
      #     query = URI.encode_www_form("config[id]" => id)
      #     redirect params[:return_url] + "?" + query
      #   else
      #     redirect params[:error_url]
      #   end
      # rescue OAuth::Unauthorized
      #   redirect params[:error_url]
      # end
    end


    post '/validate_config/' do
      # subscription_id = params[:subscription_id]
      # endpoint = params[:endpoint]
      # config = JSON.parse(params[:config])
      # id = config['id']
      # content_type :json

      # if access_token = token_store.get(:access_token, id, Kachina::Twitter.consumer)
      #   subscription_store.store(id, subscription_id, endpoint)
      #   registrations.add(id)
      #   {:valid => true}.to_json
      # else
      #   {:valid => false}.to_json
      # end
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
