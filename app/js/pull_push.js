var Classifier, Search, TwitterWatcher, classifier, events, pg, pgClient, pubnunb, redis, redisClient, searches, sys, twit, twitter, twitterWatcher;

sys = require("sys");

redis = require("redis");

redisClient = redis.createClient();

events = require('events');

pubnunb = require("pubnub");

pg = require("pg");

pgClient = pg.Client();

twitter = require("ntwitter");

twit = new twitter({
  consumer_key: process.env.TWITTER_KEY,
  consumer_secret: process.env.TWITTER_SECRET
});

Search = require("./search").Search;

searches = new Search(redisClient, pgClient);

Classifier = require("./classifier").Classifier;

classifier = new Classifier(pgClient);

TwitterWatcher = require("./twitter_watcher").TwitterWatcher;

twitterWatcher = new TwitterWatcher(twit);

searches.on("keywordsChanged", function(keywords) {
  return twitterWatcher.connect(keywords);
});

twitterWatcher.on("tweet", function(tweet) {
  return searches.tweet(tweet);
});

searches.on("match", function(searchId, tweet) {
  return classifier.classify(searchId, tweet);
});

classifier.on("classified", function(tweet, searchId, category) {
  if (category !== Classifier.INTERESTING) return;
  return pubnub.publish({
    channel: "search:" + searchId + ":tweets:add",
    message: {
      tweet: tweet
    }
  });
});

redisClient.subscribe("modelUpdates");

redisClient.on("message", function(channel, data) {
  var message;
  console.log("msg on " + channel);
  if (channel !== "modelUpdates") return;
  message = JSON.parse(data);
  switch (message.type) {
    case "Search":
      return Search.update(message);
    case "ClassifiedTweet":
      return classifier.train("train", data.searchId, data.tweet, data.category);
  }
});

module.exports = {};
