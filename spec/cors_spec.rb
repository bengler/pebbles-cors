require 'spec_helper'
require "rack/test"
require "pebbles-cors"
require "ostruct"

describe Pebbles::Cors do
  include Rack::Test::Methods

  describe "Request handling" do
    let(:realm_response) {
      OpenStruct.new({
                       body: {
                         realm: {
                           label: "some-realm",
                           domains: ["client-domain.com", "another-domain.net"]
                         }
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

      Pebblebed::Http.should_receive(:get).once.and_return realm_response

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

      Pebblebed::Http.should_receive(:get).once.and_return realm_response

      Pebbles::Cors.new(app).call(request)

      status, headers, body = Pebbles::Cors.new(app).call(request)

      headers['Access-Control-Allow-Credentials'].should be_true
      headers.should include 'Access-Control-Max-Age'
      headers['Access-Control-Allow-Methods'].should eq request_methods
      headers['Access-Control-Allow-Headers'].should eq request_headers
      body.should be_empty
    end

    it 'takes an optional block that resolves the list of trusted domains for a domain' do

      request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                          'HTTP_ORIGIN' => "http://client-domain.com"

      app = lambda do |env|
        [200, {}, protected_data]
      end

      m = Pebbles::Cors.new(app) do
        ['client-domain.com']
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
  end
end
