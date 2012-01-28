var Search, assert, redis, tests;

assert = require("assert");

redis = require("redis").createClient();

Search = require("../app/js/search").Search;

assert.sameMembers = function(a, b, message) {
  if (message == null) {
    message = "arrays not equal " + (a.join(" ")) + ",  " + (b.join(" "));
  }
  if (a.length === b.length) {
    return a.every(function(m, i) {
      return b[i] === m;
    });
  } else {
    return false;
  }
};

tests = [
  function() {
    var search;
    search = new Search({
      hgetall: function(key, cb) {
        return cb(null, {
          "foo": 1
        });
      }
    }, {
      query: function() {}
    });
    search.on("keywordsChanged", function(keywords) {
      return assert.deepEqual(["foo"], keywords, "emits keywords");
    });
    return search.updateKeywords();
  }, function() {
    var expected, search, testSearchCreated;
    search = new Search(redis, {
      query: function() {}
    });
    search.update({
      id: 15,
      changed: {
        keywords: "foo, bar, baz"
      }
    });
    expected = ["foo", "bar", "baz"];
    testSearchCreated = function() {
      redis.get("searches:15", function(err, search) {
        return assert.sameMembers(expected, JSON.parse(search).or);
      });
      return redis.sismember("searches", 15, function(err, member) {
        return assert(member, "should be recorded as search");
      });
    };
    return search.on("keywordsChanged", function(keywords) {
      assert.sameMembers(expected, keywords, "stores keywords");
      return testSearchCreated();
    });
  }
];

tests.forEach(function(t) {
  redis.flushall();
  return t();
});
