assert = require "assert"
text = require "../app/text"

tests = [
  ->
    keywords = text.search.toQueries "a, b c,\n\t\t d \t\t\n e      f, g "
    assert.deepEqual [["a"],["b","c"],["d","e","f"],["g"]], keywords, "cleans up keywords"
  ->
    query1 = "things football, bird watching, stuff"
    query2 = "football things, watching bird, stuff"
    assert.deepEqual text.search.toQueries(query1), text.search.toQueries(query2)
  ->
    forPubnub = {}
    tweet = exampleTweet
    [
      "coordinates"
      "created_at"
      "in_reply_to_user_id_str"
      "id"
      "in_reply_to_status_id_str"
      "retweet_count"
      "text"
    ].forEach (key) ->
      forPubnub[key] = tweet[key]
    forPubnub.user = {}
    [
      "name"
      "screen_name"
      "profile_image_url_https"
    ].forEach (key) ->
      forPubnub.user[key] = tweet.user[key]
    forPubnub.user.id = tweet.user.id_str
    console.log JSON.stringify(forPubnub).length
]


exampleTweet = {
  "coordinates": null,
  "created_at": "Sat Sep 10 22:23:38 +0000 2011",
  "truncated": false,
  "favorited": false,
  "id_str": "112652479837110273",
  "entities": {
    "urls": [
      {
        "expanded_url": "http://instagr.am/p/MuW67/",
        "url": "http://t.co/6J2EgYM",
        "indices": [
          67,
          86
        ],
        "display_url": "instagr.am/p/MuW67/"
      }
    ],
    "hashtags": [
      {
        "text": "tcdisrupt",
        "indices": [
          32,
          42
        ]
      }
    ],
    "user_mentions": [
      {
        "name": "Twitter",
        "id_str": "783214",
        "id": 783214,
        "indices": [
          0,
          8
        ],
        "screen_name": "twitter"
      },
      {
        "name": "Picture.ly",
        "id_str": "334715534",
        "id": 334715534,
        "indices": [
          15,
          28
        ],
        "screen_name": "SeePicturely"
      },
      {
        "name": "Bosco So",
        "id_str": "14792670",
        "id": 14792670,
        "indices": [
          46,
          58
        ],
        "screen_name": "boscomonkey"
      },
      {
        "name": "Taylor Singletary",
        "id_str": "819797",
        "id": 819797,
        "indices": [
          59,
          66
        ],
        "screen_name": "episod"
      }
    ]
  },
  "in_reply_to_user_id_str": "783214",
  "text": "@twitter meets @seepicturely at #tcdisrupt cc.@boscomonkey @episod http://t.co/6J2EgYM",
  "contributors": null,
  "id": 112652479837110273,
  "retweet_count": 0,
  "in_reply_to_status_id_str": null,
  "geo": null,
  "retweeted": false,
  "possibly_sensitive": false,
  "in_reply_to_user_id": 783214,
  "place": null,
  "source": "<a href=\"http://instagr.am\" rel=\"nofollow\">Instagram</a>",
  "user": {
    "profile_sidebar_border_color": "eeeeee",
    "profile_background_tile": true,
    "profile_sidebar_fill_color": "efefef",
    "name": "Eoin McMillan ",
    "profile_image_url": "http://a1.twimg.com/profile_images/1380912173/Screen_shot_2011-06-03_at_7.35.36_PM_normal.png",
    "created_at": "Mon May 16 20:07:59 +0000 2011",
    "location": "Twitter",
    "profile_link_color": "009999",
    "follow_request_sent": null,
    "is_translator": false,
    "id_str": "299862462",
    "favourites_count": 0,
    "default_profile": false,
    "url": "http://www.eoin.me",
    "contributors_enabled": false,
    "id": 299862462,
    "utc_offset": null,
    "profile_image_url_https": "https://si0.twimg.com/profile_images/1380912173/Screen_shot_2011-06-03_at_7.35.36_PM_normal.png",
    "profile_use_background_image": true,
    "listed_count": 0,
    "followers_count": 9,
    "lang": "en",
    "profile_text_color": "333333",
    "protected": false,
    "profile_background_image_url_https": "https://si0.twimg.com/images/themes/theme14/bg.gif",
    "description": "Eoin's photography account. See @mceoin for tweets.",
    "geo_enabled": false,
    "verified": false,
    "profile_background_color": "131516",
    "time_zone": null,
    "notifications": null,
    "statuses_count": 255,
    "friends_count": 0,
    "default_profile_image": false,
    "profile_background_image_url": "http://a1.twimg.com/images/themes/theme14/bg.gif",
    "screen_name": "imeoin",
    "following": null,
    "show_all_inline_media": false
  },
  "in_reply_to_screen_name": "twitter",
  "in_reply_to_status_id": null
}


tests.forEach (t,i) ->
  console.log "Running test #{i}..."
  t()


