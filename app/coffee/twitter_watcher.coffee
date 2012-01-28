url = require("url")
readUrl = (text) ->
  data = url.parse(text)
  [
    data.hostname
    data.pathname.replace("/"," ")
    data.query?.replace(/&=/," ")
  ].join " "
tweetToString = (tweet) ->
  [
    tweet.text
    tweet.in_reply_to_screen_name
    tweet.user.name
    tweet.user.description
    tweet.entities.urls?.map((url) ->
      readUrl url.expanded_url || url.url
    ).join(" ")
    tweet.entities.media?.map((media) ->
      readUrl media.expanded_url || media.url
    ).join(" ")
  ].map((text) ->
    (text || "").toLowerCase()
  ).join("")

class TweetWatcher extends require("events").EventEmitter
  constructor: (@twit) ->
    this
  makeStream: (keywords, established) ->
    twitterEvents = this
    @twit.stream "statuses/filter", {track:keywords}, (stream) =>
      established(stream)
      stream.on "data", (data) =>
        data.keywords = tweetToString data
        twitterEvents.emit("tweet",data)
      stream.on "end", =>
        @connect(keywords)
      stream.on "destroy", =>
        @connect(keywords)

  connect: (keywords) ->
    # load keywords, establish stream
    @makeStream keywords, (newStream) =>
      if @stream
        @stream.removeAllListeners("end")
        @stream.removeAllListeners("destroy")
        @stream.destroy()
      @stream = newStream

exports.TweetWatcher = TweetWatcher
exports.tweetToString = tweetToString
