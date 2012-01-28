var possessives, quotes, separators, stemmer, text, trailingWS, twitterCommands, url, _;

url = require("url");

_ = require("underscore");

stemmer = require("../js/stemmer").stemmer;

trailingWS = /^\s+|\s+$/;

separators = /[,;\-\.!?\(\)\{\}\[\]"&:*]/g;

quotes = /\B["']\b|\b["']\B/;

twitterCommands = /[#@]/g;

possessives = /'s/g;

module.exports = text = {
  textToTrimmedWords: function(phrase) {
    if (phrase == null) phrase = "";
    return phrase.split(" ").map(function(word) {
      return word.toLowerCase().replace(trailingWS, "").replace(separators, " ").replace(quotes, "");
    }).filter(function(word) {
      return !/^\s*$/.test(word);
    });
  },
  twitterTextToKeywords: function(phrase) {
    if (phrase == null) phrase = "";
    return text.textToTrimmedWords(text.removeTwitterCommands(phrase.replace(possessives, "")));
  },
  textToKeywords: function(phrase) {
    return this.textToTrimmedWords(phrase);
  },
  removeTwitterCommands: function(text) {
    return text.replace(twitterCommands, " ");
  },
  readUrl: function(text) {
    var data, _ref;
    data = url.parse(text);
    return [data.hostname, data.pathname.replace("/", " "), (_ref = data.query) != null ? _ref.replace(/&=/, " ") : void 0].join(" ");
  },
  tweetToKeywords: function(tweet) {
    var _ref, _ref2;
    return _.flatten([
      tweet.text, tweet.in_reply_to_screen_name, tweet.user.name, tweet.user.screen_name, tweet.user.description, (_ref = tweet.entities.urls) != null ? _ref.map(function(url) {
        return text.readUrl(url.expanded_url || url.url);
      }).join(" ") : void 0, (_ref2 = tweet.entities.media) != null ? _ref2.map(function(media) {
        return text.readUrl(media.expanded_url || media.url);
      }).join(" ") : void 0
    ].map(function(phrase) {
      return text.twitterTextToKeywords(phrase);
    }));
  }
};
