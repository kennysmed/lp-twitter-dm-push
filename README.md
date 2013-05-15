# Twitter Direct Messages Push publication

In progress.

## Environment variables

    # Number of seconds.
    AHOLA_KEEPALIVE

    # URL to ping to keep things running, eg publication's root level URL.
    AHOLA_URL

    # Created when you add the RedisCloud Heroku add-on.
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



    uri = URI.parse(ENV['REDISCLOUD_URL'])
    redis = ::Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    redis.keys
