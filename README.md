# Twitter Direct Messages Push publication for Little Printer

This is a [Little Printer](http://bergcloud.com/littleprinter/) publication which will send a user's Twitter Direct Messages to their Little Printer via the Push API. It is written in Ruby using the Sinatra framework.

**NOTE:** This uses [Twitter Site Streams](https://dev.twitter.com/docs/streaming-apis/streams/site) which at the time of writing (7 Oct 2013) are in a limited, whitelisted beta.

A Little Printer user will be able to subscribe to this publication, authenticating with their Twitter account in the process. When they get sent a Direct Message on Twitter, it will be sent to their Little Printer a few seconds later.

You will need:

* A [Twitter app](https://dev.twitter.com/apps/) and its OAuth tokens (the access token should have an access level of "Read, write and direct messages").

* A BERG Cloud publication and its OAuth tokens (see the [Push API
  documentation](http://remote.bergcloud.com/developers/reference/push)).

* A Redis database. The app currently assumes either a database on localhost, or else a `REDISCLOUD_URL` setting (eg, using the [Redis Cloud add-on](https://addons.heroku.com/rediscloud) while hosting on Heroku).

The app can be started locally using:

	$ foreman start


## NOTE when running tests

When running tests, `ENV['RACK_ENV']` is set to `test` and, if there's no `rediscloud_url` set, uses the local Redis database `2` (`0` is the default otherwise).  **Database `2` will be emptied at various points in the tests**, so don't use it for anything persistent!

Also, during tests, config data is read from `config.yml.test` rather than anything in `config.yml` or environment variables. Run the tests with:

	$ rspec spec/


## Environment variables

All the settings are required unless marked optional.

    # Number of seconds (optional, defaults to 1200).
    KEEPALIVE_TIME 

    # URL to ping to keep things running, and link to images in CSS.
    # The  publication's root level URL.
    # eg http://my-app-name.herokuapp.com/
    BASE_URL

    # Created when you add the RedisCloud Heroku add-on. Optional.
    # If not present, then it's assumed Redis is running on localhost.
	# eg redis://rediscloud:ABCDEFGHIJKLMNOP@pub-redis-12345.eu-west-1-1.2.ec2.garantiadata.com:12345
    REDISCLOUD_URL

    # From your Twitter application's Details page. You will need an app that
	has 'Read, write and direct messages' permissions, and access to Site Streams.
    TWITTER_CONSUMER_KEY
    TWITTER_CONSUMER_SECRET
	TWITTER_ACCESS_TOKEN
	TWITTER_ACCESS_TOKEN_SECRET

    # From the bottom of your publication's page in Remote > Your publications.
    BERGCLOUD_CONSUMER_KEY
    BERGCLOUD_CONSUMER_SECRET
    BERGCLOUD_ACCESS_TOKEN
    BERGCLOUD_ACCESS_TOKEN_SECRET

Alternatively, these can all be set in a `config.yml` file at the same level as `twitterpush.rb`. All the keys should be lowercase, eg:

	keepalive_time: 1200
	base_url: http://0.0.0.0:5000/
	...


## Trial scripts

`trial_scripts/` contains three scripts for trying out various things on the command line. They're left here in case they're useful. They use the same `config.yml` file as the main application (the User Streams example needing extra variables).


## TODO

* If a user de-authenticates their Twitter account from our Twitter app, we don't currently find out. Maybe we should periodically get info about a Control Stream, compare the users Twitter says are on it (and their permissions) with those who *we* think are on it, and remove those who we shouldn't now be streaming.

----

BERG Cloud Developer documentation: http://remote.bergcloud.com/developers/

