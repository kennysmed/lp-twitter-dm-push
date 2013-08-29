# Twitter Direct Messages Push publication

In progress. Start with:

	$ forman start


## Environment variables

    # Number of seconds.
    KEEPALIVE_TIME 

    # URL to ping to keep things running, and link to images in CSS.
    # The  publication's root level URL.
    # eg http://my-app-name.herokuapp.com/
    BASE_URL

    # Created when you add the RedisCloud Heroku add-on. Optional.
    # If not present, then it's assumed Redis is running on localhost.
    REDISCLOUD_URL

    # From your Twitter application's Details page.
    TWITTER_CONSUMER_KEY
    TWITTER_CONSUMER_SECRET

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


