class TweetWatcher extends require("events").EventEmitter
  constructor: (@twit) ->

  makeStream: (keywords, established) ->
    twitterEvents = this
    @twit.stream "statuses/filter", keywords, (stream) ->
      established()
      stream.on "data", (data) ->
        text = data.text.replace(/#;,.;/," ").replace("[^\d\w]","")
        twitterEvents.emit("tweet",text,tweet)

  connect: (keywords) ->
    # load keywords, establish stream
    newStream = makeStream =>
      @stream?.destroy()
      @stream = newStream
