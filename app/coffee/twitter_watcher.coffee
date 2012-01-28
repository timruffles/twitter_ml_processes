text = require "./text"
logger = require "./logger"

class TweetWatcher extends require("events").EventEmitter
  constructor: (@twit) ->
    this
  makeStream: (keywords, established) ->
    twitterEvents = this
    return if keywords.length == 0
    @twit.stream "statuses/filter", {track:keywords.join(",")}, (stream) =>
      logger.log "Connection established, tracking #{keywords.length} keywords"
      timeout = +new Date + 15000
      timer = =>
        setTimeout (=>
          if +new Date >= timeout
            logger.log "timeout, reconnecting"
            @connect keywords
          else
            timer()
        ), 18000
      timer()
      established(stream)
      stream.on "data", (data) =>
        timeout += 5000
        logger.log "Tweet received, #{data.id}, #{data.text}"
        twitterEvents.emit("tweet",data)
      stream.on "end", =>
        logger.log "Tweet stream ended"
        @connect(keywords)
      stream.on "destroy", =>
        logger.log "Tweet stream destroyed"
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
