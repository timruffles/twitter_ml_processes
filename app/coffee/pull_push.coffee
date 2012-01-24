sys = require("sys")
twitter = require("ntwitter")

twit = new twitter
  consumer_key: "STATE YOUR NAME"
  consumer_secret: "STATE YOUR NAME"
  access_token_key: "STATE YOUR NAME"
  access_token_secret: "STATE YOUR NAME"

pg = require("pg")
redisLib = require("redis")
redisClient = redisLib.createClient()

events = require('events')

conString = "tcp://postgres:1234@localhost/postgres"
pgClient = new pgLib.Client(conString)

redisClient.subscribe("searchUpdates")
redisClient.on "newSearch", (channel,msg) ->
  
keywordEvents = new events.EventEmitter
twit.stream "statuses/filter", (stream) ->
  stream.on "data", (data) ->
    text = data.text.replace(/#;,.;/," ").replace("[^\d\w]","")
    keywordEvents.emit("keywords",text,tweet)

extract = (keys,obj) ->
  view = {}
  keys.forEach (key) ->
    view[key] = obj[key]
  view

keywordEvents.on "keywords", (text,tweet) ->
  words = text.split(" ")
  words.forEach (word) ->
    redisClient.smembers "or_#{word}", (memberIds) ->
      pubnub.publish
        channel : "user:#{id}:tweets:add"
        message : extract ["text","id","created_at"]

  # naive but manageable phrase handelling - exact match
  phrases = text.split(",").filter (text) ->
    trimmed = text.replace(/^\s+/,"").replace(/\s+$/,"")
    trimmed.split(" ").length > 1
  phrases.filter (phrase) ->
    redisClient.isMember "phrase_#{phrase}"

pubnub = require("pusher")

