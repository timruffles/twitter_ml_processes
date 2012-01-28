var Classifier, brain, pubnub, stemmer, text,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

brain = require("brain");

pubnub = require("pubnub");

stemmer = require("../js/stemmer").stemmer;

text = require("../js/text");

Classifier = Classifier = (function(_super) {
  var BORING, INTERESTING;

  __extends(Classifier, _super);

  Classifier.INTERESTING = INTERESTING = "interesting";

  Classifier.BORING = BORING = "boring";

  function Classifier(pg) {
    this.pg = pg;
  }

  Classifier.prototype.getBayes = function(searchId) {
    return new brain.BayesianClassifier({
      backend: {
        type: 'memory',
        options: {
          hostname: 'localhost',
          port: 6379,
          name: "tweet_classifications:" + searchId
        }
      },
      thresholds: {
        boring: 1,
        interesting: 3
      },
      def: INTERESTING
    });
  };

  Classifier.prototype.classificationString = function(tweet) {
    return text.tweetToKeywords(tweet).map(function(word) {
      return stemmer(word);
    }).join(" ");
  };

  Classifier.prototype.train = function(searchId, tweet, category) {
    console.log("train on ", this.classificationString(tweet));
    return this.getBayes(searchId).train(this.classificationString(tweet), category);
  };

  Classifier.prototype.classify = function(tweet, searchId) {
    var classifiedEvents, pg;
    classifiedEvents = this;
    pg = this.pg;
    return this.getBayes(searchId).classify(this.classificationString(tweet), function(category) {
      tweet.category = category;
      classifiedEvents.emit("classified", tweet, searchId, category);
      return pg.query("INSERT INTO classified_tweets (search_id, tweet_id, category) VALUES ($1, $2, $3)", [searchId, tweet.id, category]);
    });
  };

  return Classifier;

})(require("events").EventEmitter);

module.exports.Classifier = Classifier;
