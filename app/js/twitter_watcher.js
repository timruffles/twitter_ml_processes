var TweetWatcher, text,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

text = require("text");

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
    return this.twit.stream("statuses/filter", {
      track: keywords
    }, function(stream) {
      established(stream);
      stream.on("data", function(data) {
        data.keywords = tweetToString(data);
        return twitterEvents.emit("tweet", data);
      });
      stream.on("end", function() {
        return _this.connect(keywords);
      });
      return stream.on("destroy", function() {
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

exports.TweetWatcher = TweetWatcher;

exports.tweetToString = tweetToString;
