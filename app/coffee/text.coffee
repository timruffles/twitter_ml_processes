url = require("url")
_ = require("underscore")
stemmer = require("../js/stemmer").stemmer

trailingWS = /^\s+|\s+$/
separators = /[,;\-\.!?\(\)\{\}\[\]"&:*]/g
quotes = /\B["']\b|\b["']\B/
twitterCommands = /[#@]/g
possessives = /'s/g

module.exports = text =
  textToTrimmedWords: (phrase = "") ->
    phrase.split(" ").map((word) ->
      word.toLowerCase()
          .replace(trailingWS,"")
          .replace(separators," ")
          .replace(quotes,"")
    ).filter (word) ->
      !/^\s*$/.test word
  twitterTextToKeywords: (phrase = "") ->
    text.textToTrimmedWords text.removeTwitterCommands phrase.replace(possessives,"")
  textToKeywords: (phrase) ->
    @textToTrimmedWords(phrase)
  removeTwitterCommands: (text) ->
    text.replace(twitterCommands," ")
  readUrl: (text) ->
    data = url.parse(text)
    [
      data.hostname
      data.pathname.replace("/"," ")
      data.query?.replace(/&=/," ")
    ].join " "
  tweetToKeywords: (tweet) ->
    _.flatten([
      tweet.text
      tweet.in_reply_to_screen_name
      tweet.user.name
      tweet.user.screen_name
      tweet.user.description
      tweet.entities.urls?.map((url) ->
        text.readUrl url.expanded_url || url.url
      ).join(" ")
      tweet.entities.media?.map((media) ->
        text.readUrl media.expanded_url || media.url
      ).join(" ")
    ].map((phrase) ->
      text.twitterTextToKeywords(phrase)
    ))

