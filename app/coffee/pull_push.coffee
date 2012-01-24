sys = require("sys")
twitter = require("ntwitter")

twit = new twitter
  consumer_key: "STATE YOUR NAME"
  consumer_secret: "STATE YOUR NAME"
  access_token_key: "STATE YOUR NAME"
  access_token_secret: "STATE YOUR NAME"

pg = require("pg")
redis = require("redis")
redisClient = redis.createClient()
pubnub = require("pubnub")

events = require('events')

conString = "tcp://postgres:1234@localhost/postgres"
pgClient = new pg.Client(conString)

app = {}
redisClient.get "keywords", (keywords) ->
  app.keywords = keywords

keywordEvents = new events.EventEmitter
makeStream = (established) ->
  twit.stream "statuses/filter", app.keywords, (stream) ->
    established()
    stream.on "data", (data) ->
      text = data.text.replace(/#;,.;/," ").replace("[^\d\w]","")
      keywordEvents.emit("tweet",text,tweet)
stream = makeStream()

userUpdates = redisClient.subscribe "userUpdates"
userUpdates.on "message", (data) ->
  redisClient.get "keywords", (keywords) ->
    app.keywords = keywords
    newStream = makeStream ->
      stream.destroy()
      stream = newStream

extract = (keys,obj) ->
  view = {}
  keys.forEach (key) ->
    view[key] = obj[key]
  view

userTweetEvents = new events.EventEmitter
keywordEvents.on "tweet", (text,tweet) ->
  words = text.split(" ")
  words.forEach (word) ->
    redisClient.smembers "or_#{word}", (memberIds) ->
      memberIds.forEach (id) ->
        userTweetEvents.emit "user-tweet", id, tweet

P_GOOD_MIN = 0.3
P_BAX_MAX = 0.3
userTweetEvents.on "tweet", (userId,tweet) ->
  crm.classify userId,tweet, (pGood,pBad) ->
    if pGood > P_GOOD_MIN && pBad < P_BAD_MAX
      pubnub.publish
        channel : "user:#{id}:tweets:add"
        message : extract ["text","id","created_at"], tweet


