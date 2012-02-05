brain = require("brain")
stemmer = require("../js/stemmer").stemmer
text = require("../js/text")
logger = require("./logger")
# ## User updates
Classifier = class Classifier extends require("events").EventEmitter

  this.INTERESTING = INTERESTING = "interesting"
  this.BORING = BORING = "boring"

  constructor: (@pg) ->
  getBayes: (searchId) ->
    new brain.BayesianClassifier
      backend :
        type: 'redis'
        options:
          hostname: 'localhost'
          port: 6379
          name: "tweet_classifications:#{searchId}" # namespace so you can persist training
      thresholds:
        boring: 1
        interesting: 3
      def: INTERESTING # category if can't classify

  classificationString: (tweet) ->
    # for now, let's simply classify like this
    text.tweetToKeywords(tweet).map((word) ->
      stemmer(word)
    ).join(" ")

  train: (searchId,tweet,category) ->
    console.log("train on ",@classificationString(tweet))
    @getBayes(searchId).train(@classificationString(tweet),category)

  classify: (searchId, tweet) ->
    classifiedEvents = this
    pg = @pg
    @getBayes(searchId).classify @classificationString(tweet), (category) ->
      logger.info "classified #{tweet.id} as #{category}"
      tweet.category = category
      classifiedEvents.emit "classified", tweet, searchId, category
      # store the tweet's classification for if user isn't online right now
      pg.query "INSERT INTO classified_tweets (search_id, tweet_id, category) VALUES ($1, $2, $3)", [searchId, tweet.id, category]
  classifyAs: (searchId,tweet,category) ->
    @pg.query "INSERT INTO classified_tweets (search_id, tweet_id, category) VALUES ($1, $2, $3)", [searchId, tweet.id, category]
    @emit "classified", tweet, searchId, category

module.exports.Classifier = Classifier
