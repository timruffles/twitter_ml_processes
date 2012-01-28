var Search, text, _,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

text = require("./text");

_ = require("underscore");

Search = (function(_super) {

  __extends(Search, _super);

  function Search(redis, pg) {
    this.redis = redis;
    this.pg = pg;
  }

  Search.prototype.update = function(event) {
    var search, searchKey,
      _this = this;
    search = this.keywords2query(event.changed.keywords);
    searchKey = "searches:" + event.id;
    return this.redis.get(searchKey, function(err, existing) {
      var added, deleted;
      if (existing) {
        existing = JSON.parse(existing);
        deleted = existing.filter(function(word) {
          return search.or.indexOf(word) < 0;
        });
        added = search.filter(function(word) {
          return existing.or.indexOf(word) < 0;
        });
        deleted.forEach(function(word) {
          _this.redis.srem("or_" + word, event.id);
          return _this.redis.hincrby("or_keywords", word, -1);
        });
      } else {
        added = search.or;
      }
      _this.redis.set(searchKey, JSON.stringify(search));
      _this.redis.sadd("searches", event.id);
      added.forEach(function(word) {
        _this.redis.sadd("or_" + word, event.id);
        return _this.redis.hincrby("or_keywords", word, 1);
      });
      return _this.updateKeywords();
    });
  };

  Search.prototype.updateKeywords = function() {
    var _this = this;
    return this.redis.hgetall("or_keywords", function(err, keywords) {
      return _this.emit("keywordsChanged", _this.makeKeywords(keywords));
    });
  };

  Search.prototype.makeKeywords = function(keywords) {
    return Object.keys(keywords);
  };

  Search.prototype.tweet = function(tweet) {
    var searchTweetEvents,
      _this = this;
    text = text.tweetToKeywords(tweet.text);
    searchTweetEvents = this;
    words.forEach(function(word) {
      return _this.redis.smembers("or_" + word, function(searchIds) {
        return searchIds.forEach(function(id) {
          return searchTweetEvents.emit("match", id, tweet);
        });
      });
    });
    return this.pg.query("INSERT INTO tweets (id, tweet, created_at) values ($1, $2, $3)", [tweet.id, JSON.stringify(tweet), tweet.created_at]);
  };

  Search.prototype.keywords2query = function(keywords) {
    var query;
    query = {
      or: []
    };
    query.or = text.textToKeywords(keywords);
    return query;
  };

  return Search;

})(require("events").EventEmitter);

module.exports.Search = Search;
