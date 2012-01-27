var Search;
var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
  for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
  function ctor() { this.constructor = child; }
  ctor.prototype = parent.prototype;
  child.prototype = new ctor;
  child.__super__ = parent.prototype;
  return child;
};
Search = (function() {
  __extends(Search, require("events").EventEmitter);
  function Search(redis, pg) {
    this.redis = redis;
    this.pg = pg;
  }
  Search.prototype.update = function(event) {
    var added, deleted, existing, search;
    search = this.keywords2query(event.changed.keywords);
    if (existing = this.redis.get("searches:" + event.id)) {
      existing = JSON.parse(existing);
      deleted = existing.filter(function(word) {
        return search.or.indexOf(word) < 0;
      });
      added = search.filter(function(word) {
        return existing.or.indexOf(word) < 0;
      });
      deleted.forEach(function(word) {
        return this.redis.srem("or_" + word, event.id);
      });
    } else {
      added = search.or;
    }
    this.redis.set("searches:" + event.id, JSON.stringify(search));
    return added.forEach(function(word) {
      return this.redis.sadd("or_" + word, event.id);
    });
  };
  Search.prototype.tweet = function(tweet) {
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
  Search.prototype.keywords2query = function(keywords) {
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
  return Search;
})();
module.exports = Streams;