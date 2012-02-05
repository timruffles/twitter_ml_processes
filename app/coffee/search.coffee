text = require "./text"
_ = require "underscore"
class Search extends require("events").EventEmitter
  constructor: (@redis,@pg,@twitter) ->
  create: (searchId,keywords) ->
    @update searchId, keywords
    @twitter.search keywords.join(", "), include_entities: "t", (err,tweets) =>
      tweets.forEach (tweet) =>
        @emit "preTrainingMatch", tweet.id, tweet

  # rails:/app/models/search for format
  update: (searchId,keywords) ->
    search = @keywords2query keywords
    @redis.hget "searches", searchId, (err,existing) =>
      if existing
        existing = JSON.parse(existing)
        @keywordsRemoved existing.or.filter (word) ->
          search.or.indexOf(word) < 0
        , searchId
        added = search.or.filter (word) ->
          existing.or.indexOf(word) < 0
      else
        added = search.or
      @redis.hset "searches", searchId, JSON.stringify search
      @keywordsAdded added, searchId
      @updateKeywords()
  destroy: (searchId,keywords) ->
    search = @keywords2query keywords
    @keywordsRemoved search.or, searchId
    @redis.hdel "searches", searchId
  updateKeywords: ->
    @redis.hgetall "or_keywords", (err,keywordHash) =>
      keywords = Object.keys(keywordHash).filter (key) ->
        parseInt(keywordHash[key]) > 0
      @emit "keywordsChanged", keywords
  keywordsRemoved: (keywords,searchId) ->
    keywords.forEach (word) =>
      @redis.srem "or_#{word}", searchId
      @redis.hincrby "or_keywords", word, -1
  keywordsAdded: (keywords,searchId) ->
    keywords.forEach (word) =>
      @redis.sadd "or_#{word}", searchId
      @redis.hincrby "or_keywords", word, 1
  tweet: (tweet) ->
    words = text.tweetToKeywords tweet
    searchTweetEvents = this
    words.forEach (word) =>
      # or and and matches are stored in sets of searchIds who are listening
      @redis.smembers "or_#{word}", (err,searchIds) ->
        searchIds.forEach (id) ->
          searchTweetEvents.emit "match", id, tweet
      # TODO support and queries - should be reasonably simple as it's AND_WORDS * O(1) lookups
      # users.withAndWords.each (user) ->
      #   if user.words.every (word) -> tweetWords[word]
      #     searchTweetEvents.emit "match", id, tweet
    @pg.query "INSERT INTO tweets (id, tweet, created_at, updated_at) values ($1, $2, $3, $4)", [tweet.id, JSON.stringify(tweet), new Date(Date.parse(tweet.created_at)),new Date]
  keywords2query: (keywords) ->
    query = {
      or: []
      # TODO and support
    }
    query.or = text.textToKeywords keywords
    query

module.exports.Search = Search
