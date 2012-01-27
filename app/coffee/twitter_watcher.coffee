class TweetWatcher extends require("events").EventEmitter
  constructor: (@twit) ->
    this
  makeStream: (keywords, established) ->
    twitterEvents = this
    @twit.stream "statuses/filter", {track:keywords}, (stream) ->
      established(stream)
      stream.on "data", (data) ->
        text = data.text.replace(/#;,.;/," ").replace("[^\d\w]","")
        twitterEvents.emit("tweet",text,tweet)

  connect: (keywords) ->
    # load keywords, establish stream
    @makeStream keywords, (newStream) =>
      @stream?.destroy()
      @stream = newStream

exports.TweetWatcher = TweetWatcher
