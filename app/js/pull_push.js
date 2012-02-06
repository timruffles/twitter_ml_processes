var Classifier, Search, TwitterWatcher, classifier, env, events, logger, pg, pgClient, pubnub, redis, redisClient, searches, sys, twit, twitter, twitterWatcher, twitter_conf, updator,
  __slice = Array.prototype.slice;

sys = require("sys");

env = process.env;

redis = require("redis");

redisClient = redis.createClient();

events = require('events');

pubnub = require("pubnub").init({
  publish_key: env.PN_PUB,
  subscribe_key: env.PN_SUB
});

logger = require("./logger");

pg = require("pg");

pgClient = new pg.Client("postgres://" + env.PG_USER + ":" + env.PG_PASS + "@localhost/" + env.PG_DB);

pgClient.connect();

twitter = require("ntwitter");

twit = new twitter(twitter_conf = {
  consumer_key: env.TW_KEY,
  consumer_secret: env.TW_SECRET,
  access_token_key: env.TW_ACCESS_TOKEN,
  access_token_secret: env.TW_ACCESS_SECRET
});

console.log(twitter_conf);

Search = require("./search").Search;

searches = new Search(redisClient, pgClient, twit);

Classifier = require("./classifier").Classifier;

classifier = new Classifier(pgClient);

TwitterWatcher = require("./twitter_watcher").TwitterWatcher;

twitterWatcher = new TwitterWatcher(twit, redisClient);

pgClient.query("SELECT id FROM tweets", function(err, result) {
  var ids;
  logger.log("Ignoring " + result.rows.length + " tweets");
  if (result.rows.length > 1) {
    ids = result.rows.map(function(row) {
      return row.id;
    });
    redisClient.sadd.apply(redisClient, ["tweet_ids_received"].concat(__slice.call(ids)));
  }
  return searches.updateKeywords();
});

searches.on("keywordsChanged", function(keywords) {
  logger.log("keywords changed, '" + keywords + "'");
  return twitterWatcher.connect(keywords);
});

twitterWatcher.on("tweet", function(tweet) {
  logger.log("tweet received, " + tweet.id + ", " + tweet.text);
  return searches.tweet(tweet);
});

searches.on("match", function(searchId, tweet) {
  logger.log("tweet matches search " + searchId + ", " + tweet.id);
  return classifier.classify(searchId, tweet);
});

searches.on("preTrainingMatch", function(searchId, tweet) {
  logger.log("training data to send to search " + searchId + ", " + tweet.id);
  return classifier.classifyAs(searchId, tweet, Classifier.UNSEEN);
});

classifier.on("classified", function(searchId, tweet, category) {
  var forPubnub;
  logger.log("tweet classified " + searchId + ", " + tweet.id + " " + category);
  if (category === Classifier.BORING) return;
  forPubnub = {};
  ["coordinates", "created_at", "in_reply_to_user_id_str", "id_str", "in_reply_to_status_id_str", "retweet_count", "text"].forEach(function(key) {
    return forPubnub[key] = tweet[key];
  });
  forPubnub.user = {};
  ["id_str", "name", "screen_name", "profile_image_url_https"].forEach(function(key) {
    return forPubnub.user[key] = tweet.user[key];
  });
  return pubnub.publish({
    channel: "search:" + searchId + ":tweets:add",
    message: {
      tweet: forPubnub
    }
  });
});

updator = redis.createClient();

updator.subscribe("modelUpdates");

updator.on("message", function(channel, data) {
  var message;
  logger.log("msg on " + channel);
  if (channel !== "modelUpdates") return;
  message = JSON.parse(data);
  switch (message.type) {
    case "Search":
      switch (message.callback) {
        case "after_create":
          logger.log("search created, " + message.id);
          return searches.create(message.id, message.keywords);
        case "after_update":
          logger.log("search updated, " + message.id);
          return searches.update(message.id, message.keywords);
        case "after_destroy":
          logger.log("search destroyed, " + message.id);
          return searches.destroy(message.id, message.keywords);
        default:
          return logger.error("unhandled modelUpdate", message);
      }
      break;
    case "ClassifiedTweet":
      switch (message.callback) {
        case "after_update":
          logger.log("tweet changed, trained, " + message.search_id + " " + message.tweet_id + " " + message.category);
          return classifier.train("train", message.search_id, message.tweet, message.category);
        default:
          return logger.error("unhandled modelUpdate", message);
      }
  }
});

module.exports = {};
