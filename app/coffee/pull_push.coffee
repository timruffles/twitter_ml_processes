# # Backend processes
sys = require("sys")
redis = require("redis")
redisClient = redis.createClient()
events = require('events')
pubnunb = require("pubnub")

# our configuartion object
app = {}
pg = require("pg")
pgClient = pg.Client()

# ## Twitter watcher
twitter = require("ntwitter")
twit = new twitter
  consumer_key: process.env.TWITTER_CONSUMER_KEY
  consumer_secret: process.env.TWITTER_CONSUMER_SECRET
  access_token_key: process.env.TWITTER_TOKEN_KEY
  access_token_secret: process.env.TWITTER_TOKEN_SECRET

twitterEvents = new events.EventEmitter
makeStream = (established) ->
  twit.stream "statuses/filter", app.keywords, (stream) ->
    established()
    stream.on "data", (data) ->
      text = data.text.replace(/#;,.;/," ").replace("[^\d\w]","")
      twitterEvents.emit("tweet",text,tweet)

# load keywords, establish stream
stream = null
redisClient.get "keywords", (keywords) ->
  app.keywords = keywords
  stream = makeStream()

reconnect = ->
  # on keyword update, create a new stream, immediately disconnect old
  redisClient.get "keywords", (keywords) ->
    app.keywords = keywords
    newStream = makeStream ->
      stream.destroy()
      stream = newStream


# ## User updates
INTERESTING = "interesting"
BORING = "boring"

# we receive user updates here, and emit training updates
trainingEvents = new events.EventEmitter
userUpdates = redisClient.subscribe "userUpdates"
userUpdates.on "message", (channel,data) ->
  message = JSON.parse(data)
  switch message.type
    when "keywordsChanged"
      reconnect()
    when "train"
      trainingEvents.emit "train", data.userId, data.tweet, data.category

extract = (keys,obj) ->
  view = {}
  keys.forEach (key) ->
    view[key] = obj[key]
  view

# ## Classification stream
userTweetEvents = new events.EventEmitter
twitterEvents.on "tweet", (text,tweet) ->
  words = text.split(" ")
  words.forEach (word) ->
    # or and and matches are stored in sets of userIds who are listening
    redisClient.smembers "or_#{word}", (userIds) ->
      userIds.forEach (id) ->
        userTweetEvents.emit "match", id, tweet
    # TODO support and queries - should be reasonably simple as it's AND_WORDS * O(1) lookups
    # users.withAndWords.each (user) ->
    #   if user.words.every (word) -> tweetWords[word]
    #     userTweetEvents.emit "match", id, tweet
  pgClient.query "INSERT INTO tweets (id, tweet, created_at) values ($1, $2, $3)", [tweet.id, JSON.stringify(tweet), tweet.created_at]

brain = require("brain")
getBayes = (userId) ->
  new brain.BayesianClassifier
    backend :
      type: 'Redis'
      options:
        hostname: 'localhost'
        port: 6379
        name: "tweet_classifications:#{userId}" # namespace so you can persist training
    thresholds:
      spam: 3 # higher threshold for spam
      notspam: 1 # 1 is default threshold for all categories
    def: 'notspam' # category if can't classify

classificationString (tweet) ->
  # for now, let's simply classify like this
  tweet.text.toLowerCase()

trainingEvents.on "train", (userId,tweet,category) ->
  getBayes(userId).train(classificationString(tweet),category)

userTweetEvents.on "match", (userId,tweet) ->
  getBayes(userId).classify classificationString(tweet), (category) ->
    tweet.category = category
    # tweets pushed to interested clients as {tweet: {}} events, with #category of either 'interesting' or 'boring'
    pubnub.publish
      channel : "user:#{userId}:tweets:add"
      message :
        tweet: tweet
    # store the tweet's classification for if user isn't online right now
    pgClient.query "INSERT INTO users_tweets (user_id, tweet_id, category) VALUES ($1, $2, $3)", [userId, tweet.id, category]

module.exports = {}
