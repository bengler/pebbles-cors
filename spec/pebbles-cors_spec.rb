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

      expect(Pebblebed::Http).to receive(:get).once.and_return trusted_response

      _, headers, body = Pebbles::Cors.new(app).call(request)

      expect(headers['Access-Control-Allow-Origin']).to eq "http://client-domain.com"
      expect(headers['Vary']).to eq 'Origin'

      expect(body).to eq protected_data
    end

    it 'Ignores requests without "Origin" header and just moves along' do

      app = lambda do |env|
        [200, {}, protected_data]
      end

      request = Rack::MockRequest.env_for("http://host-domain.dev/some/resource")

      expect(Pebblebed::Http).to_not receive(:get)

      Pebbles::Cors.new(app).call(request)

      _, headers, body = Pebbles::Cors.new(app).call(request)
      expect(headers).to_not include 'Access-Control-Allow-Origin'
      expect(body).to eq protected_data
    end

    it 'Will not trust an origin if checkpoint returns a 404' do

      app = lambda do |env|
        [200, {}, protected_data]
      end

      request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                            'HTTP_ORIGIN' => "http://client-domain.com"

      expect(Pebblebed::Http).to receive(:get).once.and_raise(Pebblebed::HttpNotFoundError.new("Something was not found"))

      _, headers, body = Pebbles::Cors.new(app).call(request)

      expect(headers).to_not include 'Access-Control-Allow-Origin'
      expect(headers).to_not include 'Access-Control-Allow-Credentials'
      expect(headers).to_not include 'Access-Control-Max-Age'
      expect(headers).to_not include 'Access-Control-Allow-Methods'
      expect(headers).to_not include 'Access-Control-Allow-Headers'

      # This is expected. The browser will protect the data for us
      expect(body).to eq protected_data
    end

    it 'Will handle, but not trust invalid origins like "about:"' do

      app = lambda do |env|
        [200, {}, protected_data]
      end

      request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                            'HTTP_ORIGIN' => "about:"

      expect(Pebblebed::Http).to receive(:get).once.and_raise(Pebblebed::HttpNotFoundError.new("Something was not found"))
      _, headers, body = Pebbles::Cors.new(app).call(request)

    end

    it 'Will propagate other errors as usual and not add CORS headers if something unexpected happens' do

      app = lambda do |env|
        [200, {}, protected_data]
      end

      request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                            'HTTP_ORIGIN' => "http://client-domain.com"

      error = RuntimeError.new("Unexpected funky error")

      expect(Pebblebed::Http).to receive(:get).once.and_raise(error)
      expect(-> { Pebbles::Cors.new(app).call(request)} ).to raise_error(error)

    end

    it 'Handles a preflight request' do

      app = lambda do |env|
        [200, {}, protected_data]
      end

      request_method = "PUT"
      request_headers = "X-Some-Header"
      request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                          :method => "OPTIONS",
                                          'HTTP_ORIGIN' => "http://client-domain.com",
                                          'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => request_method,
                                          'HTTP_ACCESS_CONTROL_REQUEST_HEADERS' => request_headers

      expect(Pebblebed::Http).to receive(:get).once.and_return trusted_response

      # Will not call the app on preflighted requests (as it would most likely give 404 anyways)
      expect(app).to_not receive :call

      _, headers, body = Pebbles::Cors.new(app).call(request)

      expect(headers).to include 'Access-Control-Max-Age'
      expect(headers['Access-Control-Allow-Credentials']).to eq 'true'
      expect(headers['Access-Control-Allow-Methods']).to eq request_method
      expect(headers['Vary']).to eq 'Origin'
      expect(headers['Access-Control-Allow-Headers']).to eq request_headers
      expect(body).to be_empty
    end

    it 'It will not redirect the request to the app if its a preflight from a denied origin' do

      app = lambda do |env|
        [200, {}, protected_data]
      end

      request_method = "DELETE"
      request_headers = "X-Some-Header"
      request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                          :method => "OPTIONS",
                                          'HTTP_ORIGIN' => "http://disallowed-domain.com",
                                          'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => request_method,
                                          'HTTP_ACCESS_CONTROL_REQUEST_HEADERS' => request_headers

      expect(Pebblebed::Http).to receive(:get).once.and_return distrusted_response

      expect(app).to_not receive :call

      _, headers, body = Pebbles::Cors.new(app).call(request)

      expect(headers).to_not include 'Access-Control-Allow-Origin'
      expect(headers).to_not include 'Access-Control-Allow-Credentials'
      expect(headers).to_not include 'Access-Control-Max-Age'
      expect(headers).to_not include 'Access-Control-Allow-Methods'
      expect(headers).to_not include 'Access-Control-Allow-Headers'
      expect(body).to be_empty
    end

    describe 'optional block for checking whether an origin is trusted by a domain' do
      it 'allows if the block returns true' do

        request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                            'HTTP_ORIGIN' => "http://client-domain.com"

        app = lambda do |env|
          [200, {}, protected_data]
        end

        m = Pebbles::Cors.new(app) do
          true
        end

        _, headers, body = m.call(request)
        expect(headers['Access-Control-Allow-Origin']).to eq "http://client-domain.com"
        expect(body).to eq protected_data
      end

      it 'disallows if the block returns false' do

        request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                            'HTTP_ORIGIN' => "http://client-domain.com"

        app = lambda do |env|
          [200, {}, protected_data]
        end

        m = Pebbles::Cors.new(app) do
          false
        end

        _, headers, _ = m.call(request)
        expect(headers).to_not include 'Access-Control-Allow-Origin'
        expect(headers).to_not include 'Access-Control-Allow-Credentials'
        expect(headers).to_not include 'Access-Control-Max-Age'
        expect(headers).to_not include 'Access-Control-Allow-Methods'
        expect(headers).to_not include 'Access-Control-Allow-Headers'
      end

      it 'disallows if the block returns a value' do

        request = Rack::MockRequest.env_for "http://server-domain.dev/some/resource",
                                            'HTTP_ORIGIN' => "http://client-domain.com"

        app = lambda do |env|
          [200, {}, protected_data]
        end

        m = Pebbles::Cors.new(app) do
          []
        end

        _, headers, _ = m.call(request)
        expect(headers).to_not include 'Access-Control-Allow-Credentials'
        expect(headers).to_not include 'Access-Control-Max-Age'
        expect(headers).to_not include 'Access-Control-Allow-Methods'
        expect(headers).to_not include 'Access-Control-Allow-Headers'
      end

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
      expect(headers['Access-Control-Allow-Origin']).to eq "http://localhost:8080"
      expect(body).to eq protected_data
    end

  end
end
