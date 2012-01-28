var Classifier, Search, TwitterWatcher, classifier, events, logger, pg, pgClient, pubnunb, redis, redisClient, searches, sys, twit, twitter, twitterWatcher, updator;

sys = require("sys");

redis = require("redis");

redisClient = redis.createClient();

events = require('events');

pubnunb = require("pubnub");

logger = require("./logger");

pg = require("pg");

pgClient = new pg.Client("tcp://postgres:1234@localhost/postgres");

pgClient.connect();

twitter = require("ntwitter");

twit = new twitter({
  consumer_key: process.env.TWITTER_KEY,
  consumer_secret: process.env.TWITTER_SECRET,
  access_token_key: process.env.ACCESS_TOKEN,
  access_token_secret: process.env.ACCESS_SECRET
});

Search = require("./search").Search;

searches = new Search(redisClient, pgClient);

Classifier = require("./classifier").Classifier;

classifier = new Classifier(pgClient);

TwitterWatcher = require("./twitter_watcher").TwitterWatcher;

twitterWatcher = new TwitterWatcher(twit);

searches.on("keywordsChanged", function(keywords) {
  logger.log("keywords changed, '" + keywords + "'");
  return twitterWatcher.connect(keywords);
});

searches.updateKeywords();

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
