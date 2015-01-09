var assert = require("assert");
var pebblesCors = require("./index");
var express = require("express");
var request = require("supertest");

var protectedResponse = '{"chunky": "bacon"}';


var trusted_response = {
  body: {
    allowed: true
  }
};
var distrusted_response = {
  body: {
    allowed: false
  }
};

var app = express();

app
  .use(pebblesCors())
  .get('/foo');

describe("Request handling", ()=> {
  it('allows requests from same domains', (done)=> {
    request(app)
      .get('/foo')
      .set('Origin', "http://trusted-domain.com")
      .set('Host', "trusted-domain.com")
      .expect(function(response) {
        console.log(response.get('Access-Control-Allow-Origin'));
        assert(response.get('Access-Control-Allow-Origin') == undefined)

      })
      .end(done)
  });
});