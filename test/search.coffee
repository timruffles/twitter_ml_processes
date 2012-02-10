assert = require "assert"
redis = require("redis").createClient()
Q = require "q"
Search  = require("../app/search").Search
SearchStore  = require("../app/search").SearchStore

redis.select(15)

assert.sameMembers = (a,b,message = "arrays not equal #{a.join(" ")},
  #{b.join(" ")}") ->
  if a.length == b.length
    a.every (m,i) -> b[i] == m
  else
    false

mockRedis = ->
    {
      hgetall: (key, cb) ->
        cb(null,{1:"[['foo','bar']]"},{2:"[['biz'],['bosh']]"},{3:"[['foo','bar']]"})
    }
tests =
  "#all gives back unserialised queries": ->

  "retrieves keywords": ->
    search = new SearchStore(mockRedis())
    search.all().then (searches) ->
      assert.sameMembers searches[2], [['biz'],['bosh']]
    false
  "handles search update": ->
    search = new Search(redis,{query: ->})
    search.update
      id: 15
      changed:
        keywords: "foo, bar, baz"
    expected = ["foo","bar","baz"]
    testSearchCreated = ->
      redis.get "searches:15", (err,search) ->
        assert.sameMembers expected, JSON.parse(search).or
      redis.sismember "searches", 15, (err,member) ->
        assert member, "should be recorded as search"
    search.on "keywordsChanged", (keywords) ->
      assert.sameMembers expected, keywords, "stores keywords"
      testSearchCreated()
  "stores tweet on match": (promise) ->
    stored = false
    matched = false
    search = new Search(redis,{query: ->
      stored = true})
    search.update
      id: 15
      changed:
        keywords: "foo"
    search.on "match", (id, tweet) ->
      promise.resolve()
    setTimeout ->
      search.tweet
        text: "foo"
        entities: {}
        user: {}
      assert stored, "stores in db"
    , 100
    promise


for own test, t of tests
  console.log "ensure: #{test}"
  do (test,t) ->
    deferred = new Q.defer()
    promise = t(deferred)
    if promise?.then
      passed = false
      promise.then ->
        passed = true
      setTimeout ->
        assert false, "test not passed, '#{test}'" unless passed
        redis.flushall()
      , 500
    else
      redis.flushall()

console.log(tests.length + " tests started")

