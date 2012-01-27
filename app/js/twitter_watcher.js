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
    }, __bind(function(stream) {
      established(stream);
      stream.on("data", __bind(function(data) {
        return twitterEvents.emit("tweet", data);
      }, this));
      stream.on("end", __bind(function() {
        return this.connect(keywords);
      }, this));
      return stream.on("destroy", __bind(function() {
        return this.connect(keywords);
      }, this));
    }, this));
  };
  TweetWatcher.prototype.connect = function(keywords) {
    return this.makeStream(keywords, __bind(function(newStream) {
      if (this.stream) {
        this.stream.removeAllListeners("end");
        this.stream.removeAllListeners("destroy");
        this.stream.destroy();
      }
      return this.stream = newStream;
    }, this));
  };
  return TweetWatcher;
})();
exports.TweetWatcher = TweetWatcher;