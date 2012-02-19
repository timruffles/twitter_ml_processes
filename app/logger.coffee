Logger = (@context)->
module.exports = logger =
  DEBUG: 0
  INFO: 1
  WARN: 2
  ERROR: 3
  logLevel: process.env.LOG_LEVEL || 1
  log: (msg,level = logger.INFO) ->
    if level >= logger.logLevel
      prefix = if @context then "#{@context}: " else ""
      console.log prefix + msg
  context: false
  forContext: (context) ->
    new Logger(context)
["debug","info","warn","error"].forEach (level) ->
  logger[level] = (msg) ->
    logger.log msg, logger[level.toUpperCase()]
Logger.prototype = logger
