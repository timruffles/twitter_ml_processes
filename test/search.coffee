assert = require "assert"
redis = require("redis").createClient()
Search  = require("../app/js/search").Search


assert.sameMembers = (a,b,message = "arrays not equal #{a.join(" ")},
  #{b.join(" ")}") ->
  if a.length == b.length
    a.every (m,i) -> b[i] == m
  else
    false


tests = [
  ->
    search = new Search({
      hgetall: (key, cb) ->
        cb(null,{"foo":1})
    },{query: ->})
    search.on "keywordsChanged", (keywords) ->
      assert.deepEqual ["foo"], keywords, "emits keywords"
    search.updateKeywords()
  ->
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
]

tests.forEach (t) -> 
  redis.flushall()
  t()


