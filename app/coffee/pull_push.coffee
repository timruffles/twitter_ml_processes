# # Backend processes
sys = require("sys")
redis = require("redis")
redisClient = redis.createClient()
events = require('events')
pubnunb = require("pubnub")

pg = require("pg")
pgClient = pg.Client()

twitter = require("ntwitter")
twit = new twitter
  consumer_key: process.env.TWITTER_KEY
  consumer_secret: process.env.TWITTER_SECRET

searches = new require("search")(redisClient,pgClient)
classifier = new require("classifier")(pgClient)
twitterWatcher = new require("twitter_watcher")(twit)

# start watching twitter for our keywords, updating whenever they change
searches.on "keywordsChanged", (keywords) ->
  twitterWatcher.connect(keywords)

# when a search matches a tweet, classify it to see if it's interesting
searches.on "match", (searchId,tweet) ->
  classifier.classify searchId, tweet

# if a tweet is classified as interesting, publish it in case the user is online
classifier.on "classified", (tweet,searchId,category) ->
  return unless category == Classifier.INTERESTING
  # tweets pushed to interested clients as {tweet: {}} events, with #category of either 'interesting' or 'boring'
  pubnub.publish
    channel : "search:#{searchId}:tweets:add"
    message :
      tweet: tweet

# we listen here for any modifications to our models
modelUpdates = redisClient.subscribe "modelUpdates"
modelUpdates.on "message", (channel,data) ->
  message = JSON.parse(data)
  switch message.type
    when "Search"
      Search.update(message)
    when "ClassifiedTweet"
      classifier.train "train", data.searchId, data.tweet, data.category

module.exports = {}
