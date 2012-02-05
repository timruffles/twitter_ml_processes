var Search, text, _,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

text = require("./text");

_ = require("underscore");

Search = (function(_super) {

  __extends(Search, _super);

  function Search(redis, pg, twitter) {
    this.redis = redis;
    this.pg = pg;
    this.twitter = twitter;
  }

  Search.prototype.create = function(searchId, keywords) {
    var _this = this;
    this.update(searchId, keywords);
    return this.twitter.search(keywords.join(", "), {
      include_entities: "t"
    }, function(err, tweets) {
      return tweets.forEach(function(tweet) {
        return _this.emit("preTrainingMatch", tweet.id, tweet);
      });
    });
  };

  Search.prototype.update = function(searchId, keywords) {
    var search,
      _this = this;
    search = this.keywords2query(keywords);
    return this.redis.hget("searches", searchId, function(err, existing) {
      var added;
      if (existing) {
        existing = JSON.parse(existing);
        _this.keywordsRemoved(existing.or.filter(function(word) {
          return search.or.indexOf(word) < 0;
        }, searchId));
        added = search.or.filter(function(word) {
          return existing.or.indexOf(word) < 0;
        });
      } else {
        added = search.or;
      }
      _this.redis.hset("searches", searchId, JSON.stringify(search));
      _this.keywordsAdded(added, searchId);
      return _this.updateKeywords();
    });
  };

  Search.prototype.destroy = function(searchId, keywords) {
    var search;
    search = this.keywords2query(keywords);
    this.keywordsRemoved(search.or, searchId);
    return this.redis.hdel("searches", searchId);
  };

  Search.prototype.updateKeywords = function() {
    var _this = this;
    return this.redis.hgetall("or_keywords", function(err, keywordHash) {
      var keywords;
      keywords = Object.keys(keywordHash).filter(function(key) {
        return parseInt(keywordHash[key]) > 0;
      });
      return _this.emit("keywordsChanged", keywords);
    });
  };

  Search.prototype.keywordsRemoved = function(keywords, searchId) {
    var _this = this;
    return keywords.forEach(function(word) {
      _this.redis.srem("or_" + word, searchId);
      return _this.redis.hincrby("or_keywords", word, -1);
    });
  };

  Search.prototype.keywordsAdded = function(keywords, searchId) {
    var _this = this;
    return keywords.forEach(function(word) {
      _this.redis.sadd("or_" + word, searchId);
      return _this.redis.hincrby("or_keywords", word, 1);
    });
  };

  Search.prototype.tweet = function(tweet) {
    var searchTweetEvents, words,
      _this = this;
    words = text.tweetToKeywords(tweet);
    searchTweetEvents = this;
    words.forEach(function(word) {
      return _this.redis.smembers("or_" + word, function(err, searchIds) {
        return searchIds.forEach(function(id) {
          return searchTweetEvents.emit("match", id, tweet);
        });
      });
    });
    return this.pg.query("INSERT INTO tweets (id, tweet, created_at, updated_at) values ($1, $2, $3, $4)", [tweet.id, JSON.stringify(tweet), new Date(Date.parse(tweet.created_at)), new Date]);
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
