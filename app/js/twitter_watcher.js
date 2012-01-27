var TweetWatcher;
var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
  for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
  function ctor() { this.constructor = child; }
  ctor.prototype = parent.prototype;
  child.prototype = new ctor;
  child.__super__ = parent.prototype;
  return child;
}, __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
TweetWatcher = (function() {
  __extends(TweetWatcher, require("events").EventEmitter);
  function TweetWatcher(twit) {
    this.twit = twit;
    this;
  }
  TweetWatcher.prototype.makeStream = function(keywords, established) {
    var twitterEvents;
    twitterEvents = this;
    return this.twit.stream("statuses/filter", {
      track: keywords
    }, function(stream) {
      established(stream);
      return stream.on("data", function(data) {
        var text;
        text = data.text.replace(/#;,.;/, " ").replace("[^\d\w]", "");
        return twitterEvents.emit("tweet", text, tweet);
      });
    });
  };
  TweetWatcher.prototype.connect = function(keywords) {
    return this.makeStream(keywords, __bind(function(newStream) {
      var _ref;
      if ((_ref = this.stream) != null) {
        _ref.destroy();
      }
      return this.stream = newStream;
    }, this));
  };
  return TweetWatcher;
})();
exports.TweetWatcher = TweetWatcher;