var logger;

module.exports = logger = {
  DEBUG: 0,
  INFO: 1,
  WARN: 2,
  ERROR: 3,
  logLevel: 1,
  log: function(msg, level) {
    if (level == null) level = logger.INFO;
    if (level >= logger.logLevel) return console.log(msg);
  }
};

["debug", "info", "warn", "error"].forEach(function(level) {
  return logger[level] = function(msg) {
    return logger.log(msg, level);
  };
});
