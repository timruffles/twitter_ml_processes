class Search extends require("events").EventEmitter
  constructor: (@redis,@pg) ->
  # rails:/app/models/search for format
  update: (event) ->
    search = @keywords2query event.changed.keywords
    if existing = @redis.get "searches:#{event.id}"
      existing = JSON.parse(existing)
      deleted = existing.filter (word) ->
        search.or.indexOf(word) < 0
      added = search.filter (word) ->
        existing.or.indexOf(word) < 0
      deleted.forEach (word) ->
        @redis.srem "or_#{word}", event.id
    else
      added = search.or
    @redis.set "searches:#{event.id}", JSON.stringify search
    added.forEach (word) ->
      @redis.sadd "or_#{word}", event.id
  tweet: (text,tweet) ->
    words = text.split(" ")
    searchTweetEvents = this
    words.forEach (word) ->
      # or and and matches are stored in sets of searchIds who are listening
      @redis.smembers "or_#{word}", (searchIds) ->
        searchIds.forEach (id) ->
          searchTweetEvents.emit "match", id, tweet
      # TODO support and queries - should be reasonably simple as it's AND_WORDS * O(1) lookups
      # users.withAndWords.each (user) ->
      #   if user.words.every (word) -> tweetWords[word]
      #     searchTweetEvents.emit "match", id, tweet
    @pg.query "INSERT INTO tweets (id, tweet, created_at) values ($1, $2, $3)", [tweet.id, JSON.stringify(tweet), tweet.created_at]
  keywords2query: (keywords) ->
    query = {
      or: []
      # TODO and support
    }
    keywords.split(",").map (phrase) ->
      words = phrase.split(" ")
      query.or = words
    query

module.exports = Streams
