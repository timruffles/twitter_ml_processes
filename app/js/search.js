var Q, Search, SearchStore, logger, text, _,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

text = require("./text");

logger = require("./logger");

_ = require("underscore");

Q = require("q").Q;

SearchStore = (function(_super) {

  __extends(SearchStore, _super);

  function SearchStore() {
    SearchStore.__super__.constructor.apply(this, arguments);
  }

  SearchStore.prototype.update = function(searchId, words) {
    var _this = this;
    return this.destroy(searchId).then(function() {
      return _this.save(searchId, keywords);
    });
  };

  SearchStore.prototype.save = function(searchId, words) {
    var query;
    query = words.sort().join(" ");
    return Q.ncall(this.redis.hset, this.redis, "searches", searchId, query);
  };

  SearchStore.prototype.destroy = function(searchId) {
    return Q.ncall(this.redis.hdel, this.redis, "searches", searchId);
  };

  SearchStore.prototype.all = function() {
    return Q.ncall(this.redis.hgetall, this.redis, "searches");
  };

  SearchStore.prototype.keywordsChanged = function() {
    var _this = this;
    return this.redis.smembers("queries", function(err, queries) {
      return _this.emit("keywordsChang ed", queries);
    });
  };

  return SearchStore;

})(require("events").EventEmitter);

Search = (function(_super) {

  __extends(Search, _super);

  function Search(redis, pg, twitter) {
    var _this = this;
    this.redis = redis;
    this.pg = pg;
    this.twitter = twitter;
    this.store = new SearchStore;
    this.store.on("keywordsChanged", function(queries) {
      return _this.emit("keywordsChanged", queries);
    });
  }

  Search.prototype.create = function(searchId, keywords) {
    var _this = this;
    this.store.save(searchId, text.textToKeywords(keywords));
    return this.twitter.search(keywords, {
      include_entities: "t"
    }, function(err, result) {
      return result["results"].forEach(function(tweet) {
        tweet.id = tweet.id_str;
        tweet.user = {
          id_str: tweet.from_user_id_str,
          screen_name: tweet.from_user,
          profile_image_url_https: tweet.profile_image_url,
          name: ""
        };
        return _this.emit("preTrainingMatch", searchId, tweet);
      });
    });
  };

  Search.prototype.update = function(searchId, rawKeywords) {
    return this.store.update(searchId, text.textToKeywords(keywords));
  };

  Search.prototype.destroy = function(searchId) {
    return this.store.destroy(searchId);
  };

  Search.prototype.tweet = function(tweet) {
    var queriesFulfilled, tweetWords, wordHash,
      _this = this;
    tweetWords = text.tweetToKeywords(tweet);
    queriesFulfilled = {};
    wordHash = tweetWords.reduce((function(hash, word) {
      hash[word] = true;
      return hash;
    }), {});
    this.store.all().then(function(searches) {
      var query, searchId, _results;
      _results = [];
      for (searchId in searches) {
        if (!__hasProp.call(searches, searchId)) continue;
        query = searches[searchId];
        if (queriesFulfilled[query] || query.split(" ").every(function(w) {
          return wordHash[w];
        })) {
          queriesFulfilled[query] = true;
          _results.push(_this.emit("match", searchId, tweet));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    });
    tweet.text = text.transliterateToUtfBmp(tweet.text);
    return this.pg.query("INSERT INTO tweets (id, tweet, created_at, updated_at) values ($1, $2, $3, $4)", [tweet.id, JSON.stringify(tweet), new Date(Date.parse(tweet.created_at)), new Date], function(err, result) {
      if (err) logger.error("Error saving tweet " + tweet.id);
      return logger.error(err);
    });
  };

  return Search;

})(require("events").EventEmitter);

module.exports.Search = Search;
