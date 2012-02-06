var TweetWatcher, logger, text,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

text = require("./text");

logger = require("./logger");

TweetWatcher = (function(_super) {

  __extends(TweetWatcher, _super);

  function TweetWatcher(twit, redis) {
    this.twit = twit;
    this.redis = redis;
    this;
  }

  TweetWatcher.prototype.makeStream = function(keywords, established) {
    var twitterEvents,
      _this = this;
    twitterEvents = this;
    if (keywords.length === 0) return;
    return this.twit.stream("statuses/filter", {
      track: keywords.map(function(k) {
        return encodeURIComponent(k);
      }).join(",")
    }, function(stream) {
      logger.info("Connection established, tracking " + keywords.length + " keywords");
      established(stream);
      stream.on("data", function(data) {
        logger.log("Tweet received, " + data.id + ", " + data.id_str + " " + data.text);
        data.id = data.id_str;
        return _this.redis.sismember("tweet_ids_received", function(e, isMember) {
          if (isMember) {
            return logger.info("Duplicate tweet, " + data.id + ", ignored");
          } else {
            _this.redis.sadd("tweet_ids_received", data.id);
            return twitterEvents.emit("tweet", data);
          }
        });
      });
      stream.on("end", function(evt) {
        logger.log("Tweet stream ended");
        logger.log(evt.statusCode);
        if (evt.statusCode === 401) {
          return logger.log("Is the system clock set correctly? " + (new Date().toString()) + " OAuth can fail if it's not");
        }
      });
      stream.on("error", function(evt) {
        logger.log("ERROR");
        return logger.log(arguments);
      });
      return stream.on("destroy", function() {
        logger.log("Tweet stream destroyed");
        return logger.log(arguments);
      });
    });
  };

  TweetWatcher.prototype.connect = function(keywords) {
    var _this = this;
    return this.makeStream(keywords, function(newStream) {
      if (_this.stream) {
        _this.stream.removeAllListeners("end");
        _this.stream.removeAllListeners("destroy");
        _this.stream.destroy();
      }
      return _this.stream = newStream;
    });
  };

  return TweetWatcher;

})(require("events").EventEmitter);

exports.TwitterWatcher = TweetWatcher;
