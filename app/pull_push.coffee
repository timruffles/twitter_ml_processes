# # Backend processes
sys = require("sys")
env = process.env
redis = require("redis")
events = require('events')
pubnub = require("pubnub").init
  publish_key: env.PN_PUB
  subscribe_key: env.PN_SUB
logger = require("./logger")
Q = require("q")
Queue = require "./queue"

console.info "Loaded libraries"

redis.debug_mode = false
redisConf = require("url").parse env.IPC_REDIS_URL
redisConf.auth = redisConf.auth.split(":")[1]
classifierRedisConf = require("url").parse env.REDISTOGO_URL
classifierRedisConf.auth = classifierRedisConf.auth.split(":")[1]

createRedisClient = ->
  logger.debug "Connecting to redis"
  client = redis.createClient(redisConf.port,redisConf.hostname)
  client.on "error", (err) ->
    logger.error "Redis client had an error"
    logger.error err
  client.auth redisConf.auth, (err,res) ->
    if err
      logger.error "Could not connect to redis!"
      throw err
    else
      logger.debug "Connected to redis"
  client
redisClient = createRedisClient()

pg = require("pg")
pgClient = new pg.Client env.DATABASE_URL
pgClient.connect()

twitter = require("ntwitter")
twit = new twitter twitter_conf = 
  consumer_key: env.TW_KEY
  consumer_secret: env.TW_SECRET
  access_token_key: env.TW_ACCESS_TOKEN
  access_token_secret: env.TW_ACCESS_SECRET

Search = require("./search").Search
searches = new Search(redisClient,pgClient,twit)
Classifier = require("./classifier").Classifier
classifier = new Classifier(pgClient,classifierRedisConf)
TwitterWatcher = require("./twitter_watcher").TwitterWatcher
twitterWatcher = new TwitterWatcher(twit,redisClient)

multi = redisClient.multi()

# start watching twitter for our keywords, updating whenever they change
searches.on "keywordsChanged", (keywords) ->
  logger.log "keywords changed, '#{keywords}'"
  twitterWatcher.connect(keywords)

twitterWatcher.on "tweet", (tweet) ->
  searches.tweet tweet

# when a search matches a tweet, classify it to see if it's interesting
searches.on "match", (searchId,tweet) ->
  logger.debug "tweet matches search #{searchId}, #{tweet.id}"
  classifier.classify searchId, tweet

classifier.on "classified", (searchId,tweet,category) ->
  logger.debug "tweet classified #{searchId}, #{tweet.id} #{category}"
  publish searchId, tweet

publish = (searchId,tweet) ->
  # tweets pushed to interested clients as {tweet: {}} events, with #category
  # of either 'interesting', 'boring' or 'unseen'
  forPubnub = {}
  [
    "coordinates"
    "created_at"
    "in_reply_to_user_id_str"
    "id"
    "in_reply_to_status_id_str"
    "retweet_count"
    "text"
  ].forEach (key) ->
    forPubnub[key] = tweet[key]
  forPubnub.user = {}
  [
    "name"
    "screen_name"
    "profile_image_url"
  ].forEach (key) ->
    forPubnub.user[key] = tweet.user[key]
  forPubnub.user.id = tweet.user.id_str
  pubnub.publish
    channel : "search:#{searchId}:tweets:add"
    message :
      tweet: forPubnub
    callback: (info) ->
      logger.debug "Pubnub response #{JSON.stringify info}"

# we listen here for any modifications to our models
modelUpdates = new Queue createRedisClient, "model_updates"
modelUpdates.on "item", (message) ->
  switch message.type
    when "Search"
      switch message.callback
        when "after_create"
          logger.log "search created, #{message.id}"
          searches.create(message.id,message.keywords)
        when "after_update"
          logger.log "search updated, #{message.id}"
          searches.update(message.id,message.keywords)
        when "after_destroy"
          logger.log "search destroyed, #{message.id}"
          searches.destroy(message.id,message.keywords)
        else
          logger.error "unhandled modelUpdate", message
    when "ClassifiedTweet"
      switch message.callback
        when "after_update"
          logger.log "tweet changed, trained, #{message.search_id} #{message.tweet_id} #{message.category}"
          classifier.train message.search_id, message.tweet, message.category
        else
          logger.error "unhandled modelUpdate", message
    when "User"
      switch message.callback
        when "after_update"
          redisClient.set "user:#{message.id}", JSON.stringify(token: message.oauth_token, secret: message.oauth_secret)
    else
      logger.error "unhandelled modelUpdate", message

logger.log "Kicking the process off!"
searches.updateKeywords()

module.exports = {}

