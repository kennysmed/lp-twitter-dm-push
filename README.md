# Twitter Direct Messages Push publication

In progress. Start with:

	$ foreman start



## NOTE when running tests

When running tests, `ENV['RACK_ENV']` is set to `test` and, if there's no `rediscloud_url` set, uses Redis database `2` (`0` is the default otherwise).  **Database `2` will be emptied at various points in the tests**, so don't use it for anything persistent!

Also, config data is read from `config.yml.test` rather than anything in
`config.yml` or environment variables.


## Environment variables

    # Number of seconds (optional, defaults to 1200).
    KEEPALIVE_TIME 

    # URL to ping to keep things running, and link to images in CSS.
    # The  publication's root level URL.
    # eg http://my-app-name.herokuapp.com/
    BASE_URL

    # Created when you add the RedisCloud Heroku add-on. Optional.
    # If not present, then it's assumed Redis is running on localhost.
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

Or, these can all be set in a `config.yml` file at the same level as
`ahola.rb`. All the keys should be lowercase, eg:

	keepalive_time: 1200
	base_url: http://0.0.0.0:5000/
	...

## Trial scripts

`trial_scripts/` contains three scripts for trying out various things on the
command line. They're left here in case they're useful. They use the same
`config.yml` file as the main application (the User Streams example needing
extra variables).

