var TweetWatcher, readUrl, tweetToString, url;
var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
  for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
  function ctor() { this.constructor = child; }
  ctor.prototype = parent.prototype;
  child.prototype = new ctor;
  child.__super__ = parent.prototype;
  return child;
}, __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
url = require("url");
readUrl = function(text) {
  var data, _ref;
  data = url.parse(text);
  return [data.hostname, data.pathname.replace("/", " "), (_ref = data.query) != null ? _ref.replace(/&=/, " ") : void 0].join(" ");
};
tweetToString = function(tweet) {
  var _ref, _ref2;
  return [
    tweet.text, tweet.in_reply_to_screen_name, tweet.user.name, tweet.user.description, (_ref = tweet.entities.urls) != null ? _ref.map(function(url) {
      return readUrl(url.expanded_url || url.url);
    }).join(" ") : void 0, (_ref2 = tweet.entities.media) != null ? _ref2.map(function(media) {
      return readUrl(media.expanded_url || media.url);
    }).join(" ") : void 0
  ].map(function(text) {
    return (text || "").toLowerCase();
  }).join("");
};
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
        data.keywords = tweetToString(data);
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
exports.tweetToString = tweetToString;