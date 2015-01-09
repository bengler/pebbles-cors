var url = require("url");

module.exports = pebblesCors;

var createCheckpoint = require("./createCheckpoint");

function pebblesCors(checkFunction, options) {

  if (typeof checkFunction !== 'function') {
    options = checkFunction;
    checkFunction = undefined;
  }
  options = options || {};

  return function pebblesCors(req, res, next) {
    if (!isCorsRequest(req)) {
      return next();
    }
    checkIsOriginTrusted(req).then(function(isTrusted) {
      if (isTrusted) {
        return allow(req, res, next);
      }
      next();
    })
    .catch(next);
  };

  function allow(req, res, next) {
    var headers = {};

    headers['Access-Control-Allow-Origin'] = req.get('Origin');
    headers['Access-Control-Expose-Headers'] = '';
    headers['Access-Control-Allow-Credentials'] = 'true';

    // For cache proxies
    headers['Vary'] = 'Origin';

    if (isPreflightRequest(req)) {

      // Its a preflight request
      headers['Content-Type'] = 'text/plain';
      // Tell the browser it can cache the result for this long (in seconds)

      headers['Access-Control-Max-Age'] = 60 * 60;

      if (req.get('Access-Control-Request-Headers')) {
        headers['Access-Control-Allow-Headers'] = req.get('Access-Control-Request-Headers');
      }
      if (req.get('Access-Control-Request-Method')) {
        headers['Access-Control-Allow-Methods'] = req.get('Access-Control-Request-Method');
      }

      res.set(headers);
      return res.type("text/plain").status(200).end('');
    }

    res.set(headers);

    return next();
  }

  function isCorsRequest(req) {
    return !!req.get('Origin');
  }

  function isPreflightRequest(req) {
    return isCorsRequest(req) && req.method.toLowerCase() === 'options'
  }

  function checkIsOriginTrusted(req) {

    var originHost = url.parse(req.get('Origin')).hostname;
    var requestHost = (req.header('x-forwarded-host') || req.get('host')).split(":")[0];

    if (originHost === 'localhost') {
      return Promise.resolve(true);
    }

    if (originHost === requestHost) {
      return Promise.resolve(true);
    }

    if (checkFunction) {
      return Promise.resolve(checkFunction(requestHost, originHost))
    }

    //memcached.fetch("#{host}_trusts_#{origin_host}", cache_ttl) do
    // todo --^

    // Check if the given origin host is allowed to do the request (or a subdomain of a trusted domain)
    var checkpoint = createCheckpoint(req.protocol+'://'+requestHost);
    return checkpoint.get("/domains/"+requestHost+"/allows/"+originHost)
      .then(function(body) {
        return body.allows;
      })
      .catch(function(error) {
        if (error.statusCode === 404) {
          return false;
        }
      });
  }
}