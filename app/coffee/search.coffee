text = require "./text"
_ = require "underscore"
class Search extends require("events").EventEmitter
  constructor: (@redis,@pg) ->
  # rails:/app/models/search for format
  update: (event) ->
    search = @keywords2query event.changed.keywords
    searchKey = "searches:#{event.id}"
    @redis.get searchKey, (err,existing) =>
      if existing
        existing = JSON.parse(existing)
        deleted = existing.or.filter (word) ->
          search.or.indexOf(word) < 0
        added = search.or.filter (word) ->
          existing.or.indexOf(word) < 0
        deleted.forEach (word) =>
          @redis.srem "or_#{word}", event.id
          @redis.hincrby "or_keywords", word, -1
      else
        added = search.or
      @redis.set searchKey, JSON.stringify search
      @redis.sadd "searches", event.id
      added.forEach (word) =>
        @redis.sadd "or_#{word}", event.id
        @redis.hincrby "or_keywords", word, 1
      @updateKeywords()
  updateKeywords: ->
    @redis.hgetall "or_keywords", (err,keywords) =>
      @emit "keywordsChanged", @makeKeywords(keywords)
  makeKeywords: (keywords) ->
    Object.keys(keywords)
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
