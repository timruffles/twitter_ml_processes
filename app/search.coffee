text = require "./text"
logger = require "./logger"
_ = require "underscore"
Q = require("q")
search = text.search
class SearchStore extends require("events").EventEmitter
  constructor: (@redis) ->
  update: (searchId,string) ->
    @_destroy(searchId).then =>
      logger.debug "update callback"
      @save(searchId,string)
  save: (searchId,string)->
    logger.debug "saving search #{searchId}"
    asQueries = search.toQueries string
    promise = @ncall @redis.hset, @redis, "searches", searchId, JSON.stringify(asQueries)
    promise.then @keywordsChanged
    promise
  destroy: (searchId) ->
    promise = @_destroy(searchId)
    promise.then @keywordsChanged
    promise
  _destroy: (searchId) ->
    logger.debug "destroying search #{searchId}"
    @ncall @redis.hdel, @redis, "searches", searchId
  all: ->
    @ncall(@redis.hgetall, @redis, "searches").then (searches = {}) ->
      Object.keys(searches).reduce ((h,k) -> 
        queries = JSON.parse(searches[k])
        h[k] = queries if queries.length > 0
        h
      ), {}
  fail: (err) ->
    logger.error "SearchStore redis error\n#{err}"
  debug: ->
    logger.debug "Got some stuff from redis"
    logger.debug arguments
  ncall: ->
    prom = Q.ncall.apply(Q,arguments)
    prom.then(@debug,@fail)
    prom
  keywordsChanged: =>
    allQueries = {}
    @all().then (searches) =>
      for own searchId, queries of searches
        for query in queries
          allQueries[query.join(" ")] = true
      @emit "keywordsChanged", Object.keys(allQueries)

class Search extends require("events").EventEmitter
  constructor: (@redis,@pg,@twitter) ->
    @store = new SearchStore(@redis)
    @store.on "keywordsChanged", (queries) =>
      @emit "keywordsChanged", queries
  updateKeywords: ->
    @store.keywordsChanged()
  create: (searchId,keywordsString) ->
    @store.save(searchId,keywordsString)
    @search searchId, keywordsString
  search: (searchId,keywords,emitAs) ->
    @twitter.search keywordsString, include_entities: "t", (err,result) =>
      return logger.error "Could not retrive tweets,\n#{err}" if err
      logger.log "Received #{result.results} tweets for new query #{keywordsString}"
      result.results.forEach (tweet) =>
        # tweet IDs are too long for JS, need to use the string everywhere
        tweet.id = tweet.id_str
        # https://dev.twitter.com/docs/api/1/get/search
        # for a joke, the tweet format is totally different in the search than streaming/REST
        tweet.user =
          id_str: tweet.from_user_id_str
          screen_name: tweet.from_user
          profile_image_url_https: tweet.profile_image_url
          name: ""
        @emit "match", searchId, tweet
  # rails:/app/models/search for format
  update: (searchId,keywordsString) ->
    @store.update(searchId,keywordsString)
    @search(search,keywordsString)
  destroy: (searchId) ->
    @store.destroy(searchId)
  tweet: (tweet) ->
    tweetWords = text.tweetToWords tweet
    queriesFulfilled = {}
    wordHash = tweetWords.reduce ((hash,word) -> hash[word] = true; hash), {}
    @store.all().then (searches) =>
      for own searchId, queries of searches
        for query in queries
          hash = query.join(" ")
          fulfilled = queriesFulfilled[hash] || query.every((w) ->
            wordHash[w]
          )
          if fulfilled
            queriesFulfilled[query] = true
            @emit "match", searchId, tweet

    tweet.text = text.transliterateToUtfBmp(tweet.text)
    @pg.query "INSERT INTO tweets (id, tweet, created_at, updated_at) values ($1, $2, $3, $4)",
              [tweet.id, JSON.stringify(tweet), new Date(Date.parse(tweet.created_at)),new Date],
              (err,result) ->
                return unless err
                if /duplicate key/.test err
                  logger.debug "Duplicate key for #{tweet.id}"
                  logger.debug err
                else
                  logger.error "Error saving tweet #{tweet.id}" if err
                  logger.error err

module.exports.SearchStore = SearchStore
module.exports.Search = Search
