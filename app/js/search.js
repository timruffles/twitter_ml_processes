var SearchWorker;
var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
  for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
  function ctor() { this.constructor = child; }
  ctor.prototype = parent.prototype;
  child.prototype = new ctor;
  child.__super__ = parent.prototype;
  return child;
}, __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
SearchWorker = (function() {
  __extends(SearchWorker, require("events").EventEmitter);
  function SearchWorker(redis, pg) {
    this.redis = redis;
    this.pg = pg;
    this.updateKeywords();
  }
  SearchWorker.prototype.update = function(event) {
    var added, deleted, existing, search, searchKey;
    search = this.keywords2query(event.changed.keywords);
    searchKey = "searches:" + event.id;
    if (existing = this.redis.get(searchKey)) {
      existing = JSON.parse(existing);
      deleted = existing.filter(function(word) {
        return search.or.indexOf(word) < 0;
      });
      added = search.filter(function(word) {
        return existing.or.indexOf(word) < 0;
      });
      deleted.forEach(__bind(function(word) {
        this.redis.srem("or_" + word, event.id);
        return this.redis.hincrby("or_keywords", word, -1);
      }, this));
    } else {
      added = search.or;
    }
    this.redis.set(searchKey, JSON.stringify(search));
    this.redis.sadd("searches", event.id);
    added.forEach(__bind(function(word) {
      this.redis.sadd("or_" + word, event.id);
      return this.redis.hincrby("or_keywords", word, 1);
    }, this));
    return this.updateKeywords();
  };
  SearchWorker.prototype.updateKeywords = function() {
    var count, keyword, keywords;
    keywords = this.redis.hgetall("or_keywords");
    return this.emit("keywordsChanged", ((function() {
      var _results;
      _results = [];
      for (keyword in keywords) {
        if (!__hasProp.call(keywords, keyword)) continue;
        count = keywords[keyword];
        if (count > 0) {
          _results.push(keyword);
        }
      }
      return _results;
    })()).join(" "));
  };
  SearchWorker.prototype.tweet = function(tweet) {
    var searchTweetEvents, text, words;
    text = tweet.text;
    text = data.text.replace(/#;,.;/, " ").replace("[^\d\w-]", "");
    words = tweet.split(" ");
    searchTweetEvents = this;
    words.forEach(function(word) {
      return this.redis.smembers("or_" + word, function(searchIds) {
        return searchIds.forEach(function(id) {
          return searchTweetEvents.emit("match", id, tweet);
        });
      });
    });
    return this.pg.query("INSERT INTO tweets (id, tweet, created_at) values ($1, $2, $3)", [tweet.id, JSON.stringify(tweet), tweet.created_at]);
  };
  SearchWorker.prototype.keywords2query = function(keywords) {
    var query;
    query = {
      or: []
    };
    keywords.split(",").map(function(phrase) {
      var words;
      words = phrase.split(" ");
      return query.or = words;
    });
    return query;
  };
  return SearchWorker;
})();
module.exports = Streams;