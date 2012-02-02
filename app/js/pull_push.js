var Classifier, Search, TwitterWatcher, classifier, env, events, logger, pg, pgClient, pubnub, redis, redisClient, searches, sys, twit, twitter, twitterWatcher, twitter_conf, updator;

sys = require("sys");

env = process.env;

redis = require("redis");

redisClient = redis.createClient();

events = require('events');

pubnub = require("pubnub").init({
  publish_key: env.PUBNUB_PUB_KEY,
  subscribe_key: env.PUBNUB_SUB_KEY
});

logger = require("./logger");

pg = require("pg");

pgClient = new pg.Client("postgres://" + env.PG_USER + ":" + env.PG_PASS + "@localhost/" + env.PG_DB);

pgClient.connect();

twitter = require("ntwitter");

twit = new twitter(twitter_conf = {
  consumer_key: env.TWITTER_KEY,
  consumer_secret: env.TWITTER_SECRET,
  access_token_key: env.ACCESS_TOKEN,
  access_token_secret: env.ACCESS_SECRET
});

console.log(twitter_conf);

Search = require("./search").Search;

searches = new Search(redisClient, pgClient);

Classifier = require("./classifier").Classifier;

classifier = new Classifier(pgClient);

TwitterWatcher = require("./twitter_watcher").TwitterWatcher;

twitterWatcher = new TwitterWatcher(twit, redisClient);

pgClient.query("SELECT id FROM tweets", function(err, result) {
  var ids;
  if (result.rows.length > 1) {
    ids = result.rows.map(function(row) {
      return row.id;
    });
    redisClient.sadd("tweet_ids_received", ids);
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

classifier.on("classified", function(tweet, searchId, category) {
  logger.log("tweet classified " + searchId + ", " + tweet.id + " " + category);
  if (category !== Classifier.INTERESTING) return;
  return pubnub.publish({
    channel: "search:" + searchId + ":tweets:add",
    message: {
      tweet: tweet
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
      logger.log("search updated, " + message.id);
      return searches.update(message);
    case "ClassifiedTweet":
      logger.log("searcords changed, 'foo bar baz'h trained, " + message.searchId + " " + message.tweetId + " " + message.category);
      return classifier.train("train", message.searchId, message.tweet, message.category);
  }
});

module.exports = {};
