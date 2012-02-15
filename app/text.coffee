url = require("url")
_ = require("underscore")
Iconv = require("iconv").Iconv

trailingWS = /^\s+|\s+$/
separators = /[,;_\-\.!?\(\)\{\}\[\]"&:*]/g
quotes = /\B["']\b|\b["']\B/
twitterCommands = /[#@]/g
possessives = /'s/g

# words = [w1,w2]
# text =String
text =
  toWords: (phrase = "") ->
    phrase.split(/\b/).map((w) -> w.trim()).filter (w) -> w != ""
  transliterateToUtfBmp: (string) ->
    new Iconv("UTF-16","UTF-8//TRANSLIT").convert(new Iconv("UTF-8","UTF-16").convert(string)).toString("UTF-8")
  normaliseWords: (phrase = "") ->
    phrase.toLowerCase()
          .replace(separators," ")
          .replace(quotes,"")
          .replace(possessives,"")
  removeTwitterCommands: (phrase = "") ->
    phrase.replace(twitterCommands," ")
  readUrl: (text) ->
    data = url.parse(text)
    [
      data.hostname
      data.pathname.replace("/"," ")
      data.query?.replace(/&=/," ")
    ].join " "
  tweetTextToWords: (phrase = "") ->
    text.toWords text.removeTwitterCommands text.normaliseWords phrase
  # returns a list of words that are stripped of symbols, normalised and stubbed
  tweetToWords: (tweet) ->
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
      text.tweetTextToWords(phrase)
    ))
module.exports = _.extend text,
  search: search = 
    # returns a set of sorted arrays representing a logical search (eg [w1,w2] = w1 && w2)
    toQueries: (phrase = "") ->
      _.uniq(phrase.split(",").map((phrase) ->
        text.toWords(phrase).sort()
      ).filter((phrase) ->
        phrase.length > 0
      ))
  classify: {}

