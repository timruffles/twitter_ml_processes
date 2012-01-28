text = require "./text"

class TweetWatcher extends require("events").EventEmitter
  constructor: (@twit) ->
    this
  makeStream: (keywords, established) ->
    twitterEvents = this
    @twit.stream "statuses/filter", {track:keywords}, (stream) =>
      established(stream)
      stream.on "data", (data) =>
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

exports.TwitterWatcher = TweetWatcher
