brain = require("brain")
stemmer = require("./libs/stemmer").stemmer
text = require("./text")
logger = require("./logger").forContext("Classifier")
_ = require("underscore")

MINIMUM_TRAINING = 10

Classifier = class Classifier extends require("events").EventEmitter

  this.INTERESTING = INTERESTING = "interesting"
  this.BORING = BORING = "boring"
  this.UNSEEN = UNSEEN = "unseen"

  constructor: (@pg,@redisConf) ->
  getBayes: (searchId) ->
    new brain.BayesianClassifier
      backend :
        type: 'redis'
        options:
          hostname: @redisConf.hostname
          port: @redisConf.port
          auth: @redisConf.auth
          # namespace so you can persist training
          name: "tweet_classifications:#{searchId}"
          error: ->
            logger.error "Classifier can't use redis"
            logger.error arguments
      thresholds:
        boring: 1
        interesting: 1
      # category if can't classify
      def: UNSEEN

  classificationString: (tweet) ->
    text.tweetToWords(tweet).map((word) ->
      stemmer(word)
    ).join(" ")

  train: (searchId,tweet,category) ->
    logger.debug("train on ",@classificationString(tweet))
    @getBayes(searchId).train(@classificationString(tweet),category)

  classify: (searchId, tweet) ->
    bayes = @getBayes(searchId)
    bayes.getCats (cats) =>
      docs = _.reduce(cats,((s,v) -> s+v),0)
      if docs > MINIMUM_TRAINING
        @getBayes(searchId).classify @classificationString(tweet), (category) =>
          logger.debug "classified #{tweet.id} as #{category}"
          tweet.category = category
          @classifyAs(searchId,tweet,category)
      else
        logger.debug "Classifying tweet for search #{searchId} as unseen as only seen #{docs} items"
        @classifyAs(searchId,tweet,UNSEEN)

  store: (searchId,tweet,category) ->
    @pg.query "INSERT INTO classified_tweets (search_id, tweet_id, category, created_at) VALUES ($1, $2, $3, $4)", [searchId, tweet.id, category,new Date]

  classifyAs: (searchId,tweet,category) ->
    @store searchId, tweet, category
    @emit "classified", searchId, tweet, category

module.exports.Classifier = Classifier
