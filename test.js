nt = require("ntwitter")
twit = new nt({ consumer_key: 'ewOAcng1F85P92EhEqyBsA',consumer_secret: 'AXCkaGsjKO8jKpVkqCl2ihLnGpMKrfb7lTtpALtPoc'
  ,access_token_key: '144946031-zPuRSRTCuEM9oVVShKFCxwgOTMqpzeDeSX3GhjOu',
access_token_secret: 'McuSkQmjICzekjhXdMgpfKYe5KTMCUnMxOARZLQXM'});
cb =  function namedCb (name) {
  return function(d){ console.log(name,d.text) };
}
function connect() {
  twit.stream("statuses/filter",{track: "cameron"},function(s) { 
    s.on("data", cb("data")) ;
    s.on("end", connect);
    s.on("destroy", connect);
  })
};
connect();