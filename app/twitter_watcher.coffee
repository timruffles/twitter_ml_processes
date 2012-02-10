text = require "./text"
logger = require "./logger"

class TweetWatcher extends require("events").EventEmitter
  constructor: (@twit,@redis) ->
    this
  makeStream: (keywords, established) ->
    twitterEvents = this
    return if keywords.length == 0
    @twit.stream "statuses/filter", {track: keyword}, (stream) =>
      logger.log "Connection established, tracking '#{track}'"
      established(stream)
      stream.on "data", (data) =>
        # tweet IDs are too long for JS, need to use the string everywhere
        logger.debug "Tweet received, #{data.id}, #{data.id_str} #{data.text}"
        data.id = data.id_str
        twitterEvents.emit("tweet",data)
      stream.on "end", (evt) =>
        logger.error "Tweet stream ended with #{evt.statusCode}"
        logger.error "Is the system clock set correctly? #{new Date().toString()} OAuth can fail if it's not" if evt.statusCode == 401
      stream.on "error", (evt) =>
        logger.error "ERROR on tweet stream"
        console.dir arguments
      stream.on "destroy", =>
        logger.error "Tweet stream destroyed"
        logger.dir arguments

  connect: (keywords) ->
    # load keywords, establish stream
    @makeStream keywords, (newStream) =>
      if @stream
        @stream.removeAllListeners("end")
        @stream.removeAllListeners("destroy")
        @stream.destroy()
      @stream = newStream

exports.TwitterWatcher = TweetWatcher
