var classifier, events, modelUpdates, pg, pgClient, pubnunb, redis, redisClient, searches, sys, twit, twitter, twitterWatcher;
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
searches = new require("search")(redisClient, pgClient);
classifier = new require("classifier")(pgClient);
twitterWatcher = new require("twitter_watcher")(twit);
searches.on("keywordsChanged", function(keywords) {
  return twitterWatcher.connect(keywords);
});
searches.on("match", function(searchId, tweet) {
  return classifier.classify(searchId, tweet);
});
classifier.on("classified", function(tweet, searchId, category) {
  if (category !== Classifier.INTERESTING) {
    return;
  }
  return pubnub.publish({
    channel: "search:" + searchId + ":tweets:add",
    message: {
      tweet: tweet
    }
  });
});
modelUpdates = redisClient.subscribe("modelUpdates");
modelUpdates.on("message", function(channel, data) {
  var message;
  message = JSON.parse(data);
  switch (message.type) {
    case "Search":
      return Search.update(message);
    case "ClassifiedTweet":
      return classifier.train("train", data.searchId, data.tweet, data.category);
  }
});
module.exports = {};