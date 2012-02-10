twitter = require("ntwitter")
env = process.env
twit = new twitter twitter_conf = 
  consumer_key: env.TW_KEY
  consumer_secret: env.TW_SECRET
  access_token_key: env.TW_ACCESS_TOKEN
  access_token_secret: env.TW_ACCESS_SECRET

track = encodeURIComponent ["valentines","obama"].join(",")
console.log "tracking '#{track}'"
twit.stream "statuses/filter", {track:["valentines","obama"]}, (stream) =>
  console.log "established"
  stream.on "data", (data) =>
    console.log data.text

