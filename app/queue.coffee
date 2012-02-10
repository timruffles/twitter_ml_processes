logger = require "./logger"

class Queue extends require("events").EventEmitter
  constructor: (createClient,@queue) ->
    @subscriber = createClient()
    @consumer = createClient()
    @subscriber.subscribe "enqueued:#{@queue}"
    @subscriber.on "message", @get
    @get()
  get: =>
    @consumer.multi()
          .lpop(@queue)
          .llen(@queue)
          .exec (err, [item,length]) =>
            if err
              return logger.error "Queue error", err
            if item
              @emit "item", JSON.parse(item) 
              logger.log "Processed item, '#{@queue}' now has #{length} items"
            @get() if length > 0

module.exports = Queue
