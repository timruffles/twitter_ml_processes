var Classifier, brain, pubnub;
var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
  for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
  function ctor() { this.constructor = child; }
  ctor.prototype = parent.prototype;
  child.prototype = new ctor;
  child.__super__ = parent.prototype;
  return child;
};
brain = require("brain");
pubnub = require("pubnub");
Classifier = Classifier = (function() {
  var BORING, INTERESTING;
  __extends(Classifier, require("events").EventEmitter);
  Classifier.INTERESTING = INTERESTING = "interesting";
  Classifier.BORING = BORING = "boring";
  function Classifier(pg) {
    this.pg = pg;
  }
  Classifier.prototype.getBayes = function(searchId) {
    return new brain.BayesianClassifier({
      backend: {
        type: 'Redis',
        options: {
          hostname: 'localhost',
          port: 6379,
          name: "tweet_classifications:" + searchId
        }
      },
      thresholds: {
        spam: 3,
        notspam: 1
      },
      def: INTERESTING
    });
  };
  Classifier.prototype.classificationString = function(tweet) {
    return tweet.text.toLowerCase();
  };
  Classifier.prototype.train = function(searchId, tweet, category) {
    return getBayes(searchId).train(classificationString(tweet), category);
  };
  Classifier.prototype.classify = function(tweet, searchId) {
    var classifiedEvents, pg;
    classifiedEvents = this;
    pg = this.pg;
    return getBayes(searchId).classify(classificationString(tweet), function(category) {
      tweet.category = category;
      classifiedEvents.emit("classified", tweet, searchId, category);
      return pg.query("INSERT INTO classified_tweets (search_id, tweet_id, category) VALUES ($1, $2, $3)", [searchId, tweet.id, category]);
    });
  };
  return Classifier;
})();
module.exports = Classifier;