# # Backend processes
sys = require("sys")
env = process.env
redis = require("redis")
redisClient = redis.createClient()
events = require('events')
pubnub = require("pubnub").init
  publish_key: env.PN_PUB
  subscribe_key: env.PN_SUB
logger = require("./logger")


pg = require("pg")
pgClient = new pg.Client "postgres://#{env.PG_USER}:#{env.PG_PASS}@localhost/#{env.PG_DB}"
pgClient.connect()

twitter = require("ntwitter")
twit = new twitter twitter_conf = 
  consumer_key: env.TW_KEY
  consumer_secret: env.TW_SECRET
  access_token_key: env.TW_ACCESS_TOKEN
  access_token_secret: env.TW_ACCESS_SECRET
console.log twitter_conf

Search = require("./search").Search
searches = new Search(redisClient,pgClient,twit)
Classifier = require("./classifier").Classifier
classifier = new Classifier(pgClient)
TwitterWatcher = require("./twitter_watcher").TwitterWatcher
twitterWatcher = new TwitterWatcher(twit,redisClient)

pgClient.query "SELECT id FROM tweets", (err,result) ->
  logger.log "Ignoring #{result.rows.length} tweets"
  if result.rows.length > 1
    ids = result.rows.map (row) -> row.id
    redisClient.sadd "tweet_ids_received", ids...
  searches.updateKeywords()

# start watching twitter for our keywords, updating whenever they change
searches.on "keywordsChanged", (keywords) ->
  logger.log "keywords changed, '#{keywords}'"
  twitterWatcher.connect(keywords)

twitterWatcher.on "tweet", (tweet) ->
  logger.log "tweet received, #{tweet.id}, #{tweet.text}"
  searches.tweet tweet

# when a search matches a tweet, classify it to see if it's interesting
searches.on "match", (searchId,tweet) ->
  logger.log "tweet matches search #{searchId}, #{tweet.id}"
  classifier.classify searchId, tweet
searches.on "preTrainingMatch", (searchId,tweet) ->
  logger.log "training data to send to search #{searchId}, #{tweet.id}"
  classifier.classifyAs searchId, tweet, Classifier.UNSEEN

# if a tweet is classified as interesting, publish it in case the user is online
classifier.on "classified", (searchId,tweet,category) ->
  logger.log "tweet classified #{searchId}, #{tweet.id} #{category}"
  return if category == Classifier.BORING
  # tweets pushed to interested clients as {tweet: {}} events, with #category of either 'interesting' or 'boring'
  forPubnub = {}
  [
    "coordinates"
    "created_at"
    "in_reply_to_user_id_str"
    "id_str"
    "in_reply_to_status_id_str"
    "retweet_count"
    "text"
  ].forEach (key) ->
    forPubnub[key] = tweet[key]
  forPubnub.user = {}
  [
    "id_str"
    "name"
    "screen_name"
    "profile_image_url_https"
  ].forEach (key) ->
    forPubnub.user[key] = tweet.user[key]
  pubnub.publish
    channel : "search:#{searchId}:tweets:add"
    message :
      tweet: forPubnub

# we listen here for any modifications to our models
updator = redis.createClient()
updator.subscribe "modelUpdates"
updator.on "message", (channel,data) ->
  logger.log "msg on #{channel}"
  return unless channel == "modelUpdates"
  message = JSON.parse(data)
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
          classifier.train "train", message.search_id, message.tweet, message.category
        else
          logger.error "unhandled modelUpdate", message

module.exports = {}
