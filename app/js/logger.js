
module.exports.log = function(msg, level) {
  if (level == null) level = "debug";
  return console.log(msg);
};
