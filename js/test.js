var assert = require("assert");
var proxyquire = require("proxyquire");

var TRUSTS_ORIGINS = {
  "site-domain.com": ['site-domain.com', 'trusted-domain.com', 'localhost']
};

var pebblesCors = proxyquire("./index", {
  './createCheckpoint': function (baseUrl) {
    return {
      get: function (endpoint) {
        // example endpoint /domains/<requestHost>/allows/<originHost>
        var [, , requestHost, , originHost] = endpoint.split("/");
        var allowed = TRUSTS_ORIGINS[requestHost] && TRUSTS_ORIGINS[requestHost].indexOf(originHost) > -1;
        return Promise.resolve({body: {allowed: allowed}})
      }
    }
  }
});
var express = require("express");
var request = require("supertest");

var app = express();

app
  .use(pebblesCors())
  .get('/foo', function (req, res, next) {
    res.status(200).json({chunky: 'bacon'});
  });

describe("Request handling from trusted domains", ()=> {

  Object.keys(TRUSTS_ORIGINS).forEach(serverHost => {
    var trustedOrigins = TRUSTS_ORIGINS[serverHost];

    trustedOrigins.forEach(trusted => {
      var origin = `http://${trusted}`;

      describe(`trusted origin ${trusted} regular requests`, ()=> {

        it('Allows the origin', done => {
          request(app)
            .get('/foo')
            .set('Origin', origin)
            .set('Host', serverHost)
            .expect('Access-Control-Allow-Origin', origin)
            .expect(JSON.stringify({chunky: "bacon"}))
            .end(done)
        });

        it('Allows credentials', done => {
          request(app)
            .get('/foo')
            .set('Origin', origin)
            .set('Host', serverHost)
            .expect('Access-Control-Allow-Credentials', 'true')
            .expect('Access-Control-Allow-Origin', origin)
            .expect(JSON.stringify({chunky: "bacon"}))
            .end(done)
        });

        it('Allows credentials', done => {
          request(app)
            .get('/foo')
            .set('Origin', origin)
            .set('Host', serverHost)
            .expect('Access-Control-Allow-Credentials', 'true')
            .expect('Access-Control-Allow-Origin', origin)
            .expect(JSON.stringify({chunky: "bacon"}))
            .end(done)
        });
      });

      describe(`trusted origin ${trusted} preflight requests`, ()=> {
        it('Allows the origin', done => {
          request(app)
            .options('/foo')
            .set('Origin', origin)
            .set('Host', serverHost)
            .expect('Access-Control-Allow-Origin', origin)
            .expect('Content-Type', /text\/plain/)
            .expect('')
            .end(done)
        });
      });
    });
  });
});

describe("Request handling from non-trusted domains", ()=> {

  var untrusted = "evil-origin.com";
  var serverHost = "site-domain.com";

  var origin = `http://${untrusted}`;

  describe(`trusted origin ${untrusted} regular requests`, ()=> {

    it('Allows the origin', done => {
      request(app)
        .get('/foo')
        .set('Origin', origin)
        .set('Host', serverHost)
        .expect((res)=> {
          assert(res.get('Access-Control-Allow-Origin') === undefined);
        })
        .expect(JSON.stringify({chunky: "bacon"}))
        .end(done)
    });

    it('Allows credentials', done => {
      request(app)
        .get('/foo')
        .set('Origin', origin)
        .set('Host', serverHost)
        .expect((res) => {
          assert(res.get('Access-Control-Allow-Credentials') === undefined);
          assert(res.get('Access-Control-Allow-Origin') === undefined);
        })
        .expect(JSON.stringify({chunky: "bacon"}))
        .end(done)
    });

    it('Allows credentials', done => {
      request(app)
        .get('/foo')
        .set('Origin', origin)
        .set('Host', serverHost)
        .expect((res) => {
          assert(res.get('Access-Control-Allow-Credentials') === undefined);
          assert(res.get('Access-Control-Allow-Origin') === undefined);
        })
        .expect(JSON.stringify({chunky: "bacon"}))
        .end(done)
    });
  });

  describe(`trusted origin ${untrusted} preflight requests`, ()=> {
    it('Allows the origin', done => {
      request(app)
        .options('/foo')
        .set('Origin', origin)
        .set('Host', serverHost)
        .expect((res) => {
          assert(res.get('Access-Control-Allow-Credentials') === undefined);
          assert(res.get('Access-Control-Allow-Origin') === undefined);
        })
        .end(done)
    });
  });
});