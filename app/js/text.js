var Iconv, possessives, quotes, separators, stemmer, text, trailingWS, twitterCommands, url, _;

url = require("url");

_ = require("underscore");

stemmer = require("../js/stemmer").stemmer;

Iconv = require("iconv").Iconv;

trailingWS = /^\s+|\s+$/;

separators = /[,;_\-\.!?\(\)\{\}\[\]"&:*]/g;

quotes = /\B["']\b|\b["']\B/;

twitterCommands = /[#@]/g;

possessives = /'s/g;

module.exports = text = {
  textToTrimmedWords: function(phrase) {
    if (phrase == null) phrase = "";
    return phrase.split(" ").map(function(word) {
      return word.replace(trailingWS, "");
    }).filter(function(word) {
      return !/^\s*$/.test(word);
    });
  },
  normaliseWords: function(phrase) {
    if (phrase == null) phrase = "";
    return phrase.toLowerCase().replace(separators, " ").replace(quotes, "").replace(possessives, "");
  },
  twitterTextToKeywords: function(phrase) {
    if (phrase == null) phrase = "";
    return text.textToTrimmedWords(text.removeTwitterCommands(text.normaliseWords(phrase)));
  },
  textToKeywords: function(phrase) {
    return this.textToTrimmedWords(phrase);
  },
  textToPhrases: function(string) {
    return string.split(",").map(function(phrase) {
      return text.textToTrimmedWords(phrase);
    });
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
  },
  transliterateToUtfBmp: function(string) {
    return new Iconv("UTF-16", "UTF-8//TRANSLIT").convert(new Iconv("UTF-8", "UTF-16").convert(string)).toString("UTF-8");
  }
};
