text = require "./text"
logger = require "./logger"

class TweetWatcher extends require("events").EventEmitter
  constructor: (@twit,@redis) ->
    this
  makeStream: (keywords, established) ->
    twitterEvents = this
    return if keywords.length == 0
    @twit.stream "statuses/filter", {track:keywords.map((k) -> encodeURIComponent(k)).join(",")}, (stream) =>
      logger.log "Connection established, tracking #{keywords.length} keywords"
      established(stream)
      stream.on "data", (data) =>
        logger.debug "Tweet received, #{data.id}, #{data.text}"
        @redis.sismember "tweet_ids_received", (e,isMember) =>
          unless isMember
            @redis.sadd "tweet_ids_received", data.id
            twitterEvents.emit("tweet",data)
          else
            logger.info "Duplicate tweet, #{data.id}, ignored"
      stream.on "end", (evt) =>
        logger.log "Tweet stream ended"
        logger.log evt.statusCode
        logger.log "Is the system clock set correctly? #{new Date().toString()} OAuth can fail if it's not" if evt.statusCode == 401
        @connect(keywords)
      stream.on "error", (evt) =>
        logger.log "ERROR"
        logger.log arguments
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
