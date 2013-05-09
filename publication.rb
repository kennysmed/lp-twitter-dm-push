# coding: utf-8
require 'oauth'
require 'sinatra'
require 'tweetstream'


enable :sessions

raise 'TWITTER_CONSUMER_KEY is not set' if !ENV['TWITTER_CONSUMER_KEY']
raise 'TWITTER_CONSUMER_SECRET is not set' if !ENV['TWITTER_CONSUMER_SECRET']


configure do
  if settings.production?
    raise 'REDISCLOUD_URL is not set' if !ENV['REDISCLOUD_URL']
    uri = URI.parse(ENV['REDISCLOUD_URL'])
    REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  else
    REDIS = Redis.new()
  end

  if settings.development?
    # So we can see what's going wrong on Heroku.
    set :show_exceptions, true
  end
end


helpers do
  def twitter_oauth_client
    OAuth::Consumer.new(
                  ENV['TWITTER_CONSUMER_KEY'], ENV['TWITTER_CONSUMER_SECRET'],
                  { site: 'https://api.twitter.com' })
  end
end


get '/' do
end

# No editions for Push publications.
# get '/edition/' do
#   erb :publication
# end


# After clicking the link on the Publication listing on BERG Cloud Remote, the
# user arrives here to authenticate with twitter.
#
# See https://dev.twitter.com/docs/auth/implementing-sign-twitter for the
# process.
#
# == Parameters
#   params['return_url'] will be the publication-specific URL we return the
#     user to after authenticating.
#
get '/configure/' do
  if !params['return_url']
    return 400, 'No return_url parameter was provided'
  end

  # Save the return URL so we still have it after authentication.
  session[:bergcloud_return_url] = params['return_url']

  oauth = twitter_oauth_client

  # OAUTH Step 1: Obtaining a request token.
  begin
    request_token = oauth.get_request_token(oauth_callback: url('/return/'))
  rescue OAuth::Unauthorized
    return 401, 'Unauthorized when asking Twitter for a token to make a request (Step 1)' 
  rescue 
    return 401, "Something went wrong when trying to authorize with Twitter (Step 1)"
  end

  if request_token.callback_confirmed?
    # It's worked so far. Save these for later.
    session[:request_token] = request_token.token
    session[:request_token_secret] = request_token.secret

    # OAUTH Step 2: Redirecting the user.
    # The user is sent to Twitter and asked to approve the publication's
    # access.
    redirect request_token.authorize_url
  else
    return 400, 'Callback was not confirmed by Twitter'
  end
end


# User has returned from authenticating at Twitter.
# We now need to complete the OAuth dance, getting an access_token and secret
# for the user, which we'll store, before passing the user's Twitter ID back
# to BERG Cloud.
#
# == Parameters
#   params[:oauth_verifier] is returned from Twitter if things went well.
#
# == Session
#   These should be set in the session:
#     * :bergcloud_return_url
#     * :request_token
#     * :request_token_secret
#
get '/return/' do
  if params[:denied]
    # TODO: We should return to Remote somehow...?
    return 500, "You chose not to authorise with Twitter. No problem, but we don't handle this very well at the moment, sorry."
  end

  if !params[:oauth_verifier]
    return 500, 'No oauth verifier was returned by Twitter'
  end

  if !session[:bergcloud_return_url]
    return 500, 'A cookie was expected, but was missing. Are cookies enabled? Please return to BERG Cloud and try again.'
  end

  return_url = session[:bergcloud_return_url]
  session[:bergcloud_return_url] = nil

  oauth = twitter_oauth_client

  # Recreate the request token using our stored token and secret.
  begin
    request_token = OAuth::RequestToken.new(oauth,
                                            session[:request_token],
                                            session[:request_token_secret])
  rescue OAuth::Unauthorized
    return 401, 'Unauthorized when trying to get a request token from Twitter (Step 2)' 
  rescue 
    return 401, "Something went wrong when trying to authorize with Twitter (Step 2)"
  end

  # Tidy up, now we've finished with them.
  session[:request_token] = session[:request_token_secret] = nil

  # OAuth Step 3: Converting the request token to an access token.
  begin
    # accesss_token will have access_token.token and access_token.secret
    access_token = request_token.get_access_token(
                                 oauth_verifier: params[:oauth_verifier])
  rescue OAuth::Unauthorized
    return 401, 'Unauthorized when trying to get an access token from Twitter (Step 3)' 
  rescue
    return 401, "Something went wrong when trying to authorize with Twitter (Step 3)"
  end

  if !access_token
    return 500, 'Unable to retrieve an access token from Twitter'
  end

  # We've finished authenticating!
  # We now need to fetch the user's ID from twitter.
  # The client will enable us to access client.current_user which contains
  # the user's data.
  client = twitter_client(access_token.token, access_token.secret)

  # Although we have the access token and secret, we still need the Twitter
  # user ID in order to actually fetch the tweets for the publication.
  begin
    user_id = client.current_user[:id]
  rescue Twitter::Error::BadRequest
    return 500, "Bad authentication data when trying to get user's Twitter info"
  rescue
    return 500, "Something went wrong when trying to get user's Twitter info"
  end

  REDIS.set("user:#{access_token.token}:user_id", user_id)
  REDIS.set("user:#{access_token.token}:secret", access_token.secret)

  # If this worked, send the user's Access Token back to BERG Cloud
  redirect "#{return_url}?config[access_token]=#{access_token.token}"
end


get '/sample/' do
  erb :publication
end


post '/validate_config/' do
end

