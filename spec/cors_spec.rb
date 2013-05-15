require 'spec_helper'
require "rack/test"
require "pebbles-cors"
require "ostruct"

describe Pebbles::Cors do
  include Rack::Test::Methods

  describe "Request handling" do
    let(:trusted_response) {
      OpenStruct.new({
                       body: {
                         allowed: true
                       }.to_json
                     })
    }
    let(:distrusted_response) {
      OpenStruct.new({
                       body: {
                         allowed: false
                       }.to_json
                     })
    }
    before(:each) do
      Pebblebed.config do
        host "checkpoint.dev"
        service :checkpoint
      end
    end

    let(:protected_data) {
      '{"chunky": "bacon"}'
    }

    it 'Identifies a request with "Origin" header' do
      app = lambda do |env|
        [200, {}, protected_data]
      end

      request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                          'HTTP_ORIGIN' => "http://client-domain.com"

      Pebblebed::Http.should_receive(:get).once.and_return trusted_response

      status, headers, body = Pebbles::Cors.new(app).call(request)

      headers['Access-Control-Allow-Origin'].should eq "http://client-domain.com"
      body.should eq protected_data
    end

    it 'Ignores requests without "Origin" header and just moves along' do

      app = lambda do |env|
        [200, {}, protected_data]
      end

      request = Rack::MockRequest.env_for("http://host-domain.dev/some/resource")

      Pebblebed::Http.should_not_receive(:get)

      Pebbles::Cors.new(app).call(request)

      status, headers, body = Pebbles::Cors.new(app).call(request)
      headers.should_not include 'Access-Control-Allow-Origin'
      body.should eq protected_data
    end

    it 'Will not trust an origin if checkpoint returns an error' do

      app = lambda do |env|
        [200, {}, protected_data]
      end

      request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                            'HTTP_ORIGIN' => "http://client-domain.com"

      Pebblebed::Http.should_receive(:get).once.and_raise

      status, headers, body = Pebbles::Cors.new(app).call(request)

      headers.should_not include 'Access-Control-Allow-Credentials'
      headers.should_not include 'Access-Control-Max-Age'
      headers.should_not include 'Access-Control-Allow-Methods'
      headers.should_not include 'Access-Control-Allow-Headers'

      # This is expected. The browser will protect the data for us
      body.should eq protected_data
    end

    it 'Handles a preflight request' do

      app = lambda do |env|
        [200, {}, protected_data]
      end

      request_methods = "POST, PUT, DELETE"
      request_headers = "X-Some-Header"
      request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                          :method => "OPTIONS",
                                          'HTTP_ORIGIN' => "http://client-domain.com",
                                          'HTTP_ACCESS_CONTROL_REQUEST_METHODS' => request_methods,
                                          'HTTP_ACCESS_CONTROL_REQUEST_HEADERS' => request_headers

      Pebblebed::Http.should_receive(:get).once.and_return trusted_response

      # Will not call the app on preflighted requests (as it would most likely give 404 anyways)
      app.should_not_receive :call

      status, headers, body = Pebbles::Cors.new(app).call(request)

      headers['Access-Control-Allow-Credentials'].should be_true
      headers.should include 'Access-Control-Max-Age'
      headers['Access-Control-Allow-Methods'].should eq request_methods
      headers['Access-Control-Allow-Headers'].should eq request_headers
      body.should be_empty
    end

    it 'It will not redirect the request to the app if its a preflight from a denied origin' do

      app = lambda do |env|
        [200, {}, protected_data]
      end

      request_methods = "POST, PUT, DELETE"
      request_headers = "X-Some-Header"
      request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                          :method => "OPTIONS",
                                          'HTTP_ORIGIN' => "http://disallowed-domain.com",
                                          'HTTP_ACCESS_CONTROL_REQUEST_METHODS' => request_methods,
                                          'HTTP_ACCESS_CONTROL_REQUEST_HEADERS' => request_headers

      Pebblebed::Http.should_receive(:get).once.and_return distrusted_response

      app.should_not_receive :call

      status, headers, body = Pebbles::Cors.new(app).call(request)

      headers.should_not include 'Access-Control-Allow-Credentials'
      headers.should_not include 'Access-Control-Max-Age'
      headers.should_not include 'Access-Control-Allow-Methods'
      headers.should_not include 'Access-Control-Allow-Headers'
      body.should be_empty
    end

    it 'takes an optional block that resolves the list of trusted domains for a domain' do

      request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                          'HTTP_ORIGIN' => "http://client-domain.com"

      app = lambda do |env|
        [200, {}, protected_data]
      end

      m = Pebbles::Cors.new(app) do
        ['http://client-domain.com']
      end

      status, headers, body = m.call(request)
      headers['Access-Control-Allow-Origin'].should eq "http://client-domain.com"
      body.should eq protected_data
    end

    it 'always allows request from localhost' do

      request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                          'HTTP_ORIGIN' => "http://localhost:8080" # port doesn't matter

      app = lambda do |env|
        [200, {}, protected_data]
      end

      m = Pebbles::Cors.new(app) do
        ['client-domain.com']
      end

      status, headers, body = m.call(request)
      headers['Access-Control-Allow-Origin'].should eq "http://localhost:8080"
      body.should eq protected_data
    end
    it 'allows a request from a sub domain of a trusted domain' do

      request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                          'HTTP_ORIGIN' => "http://sub.example.com" # port doesn't matter

      app = lambda do |env|
        [200, {}, protected_data]
      end

      m = Pebbles::Cors.new(app) do
        ['example.com']
      end

      status, headers, body = m.call(request)
      headers['Access-Control-Allow-Origin'].should eq "http://sub.example.com"
      body.should eq protected_data
    end
  end
end
