var TweetWatcher, logger, text,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

text = require("./text");

logger = require("./logger");

TweetWatcher = (function(_super) {

  __extends(TweetWatcher, _super);

  function TweetWatcher(twit) {
    this.twit = twit;
    this;
  }

  TweetWatcher.prototype.makeStream = function(keywords, established) {
    var twitterEvents,
      _this = this;
    twitterEvents = this;
    if (keywords.length === 0) return;
    return this.twit.stream("statuses/filter", {
      track: keywords.join(",")
    }, function(stream) {
      var timeout, timer;
      logger.log("Connection established, tracking " + keywords.length + " keywords");
      timeout = +(new Date) + 15000;
      timer = function() {
        return setTimeout((function() {
          if (+(new Date) >= timeout) {
            logger.log("timeout, reconnecting");
            return _this.connect(keywords);
          } else {
            return timer();
          }
        }), 18000);
      };
      timer();
      established(stream);
      stream.on("data", function(data) {
        timeout += 5000;
        logger.log("Tweet received, " + data.id + ", " + data.text);
        return twitterEvents.emit("tweet", data);
      });
      stream.on("end", function() {
        logger.log("Tweet stream ended");
        return _this.connect(keywords);
      });
      return stream.on("destroy", function() {
        logger.log("Tweet stream destroyed");
        return _this.connect(keywords);
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
