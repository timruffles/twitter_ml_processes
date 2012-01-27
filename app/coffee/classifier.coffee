brain = require("brain")
pubnub = require("pubnub")
# ## User updates
Classifier = class Classifier extends require("events").EventEmitter

  this.INTERESTING = INTERESTING = "interesting"
  this.BORING = BORING = "boring"

  constructor: (@pg) ->
  getBayes: (searchId) ->
    new brain.BayesianClassifier
      backend :
        type: 'Redis'
        options:
          hostname: 'localhost'
          port: 6379
          name: "tweet_classifications:#{searchId}" # namespace so you can persist training
      thresholds:
        spam: 3 # higher threshold for spam
        notspam: 1 # 1 is default threshold for all categories
      def: INTERESTING # category if can't classify

  classificationString: (tweet) ->
    # for now, let's simply classify like this
    tweet.text.toLowerCase()

  train: (searchId,tweet,category) ->
    getBayes(searchId).train(classificationString(tweet),category)

  classify: (tweet,searchId) ->
    classifiedEvents = this
    pg = @pg
    getBayes(searchId).classify classificationString(tweet), (category) ->
      tweet.category = category
      classifiedEvents.emit "classified", tweet, searchId, category
      # store the tweet's classification for if user isn't online right now
      pg.query "INSERT INTO classified_tweets (search_id, tweet_id, category) VALUES ($1, $2, $3)", [searchId, tweet.id, category]

module.exports = Classifier
