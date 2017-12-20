require 'rack'
require "pebbles-cors/version"
require "pebblebed"
require "dalli"

module Pebbles

  # gaargh! pebblebed will fail unless needed services are declared up front
  Pebblebed.config do
    service :checkpoint
  end

  class Cors

    attr_accessor :cache_ttl

    def initialize(app, &blk)
      @app = app
      @allows_origin_blk = blk
      @cache_ttl = 60*5 # in seconds
    end

    def trusted_origin?(request)
      # always apply cors-headers to requests coming from localhost
      return true if request.origin_host == 'localhost'

      # Check if the given origin host is allowed to do the request (or a subdomain of a trusted domain)
      cached_host_trusts_origin_host?(request.host, request.origin_host)
    end

    def call(env)
      request = CorsRequest.new(env)

      connector_options = {
        :host => request.host,
        :scheme => request.scheme
      }
      @checkpoint ||= Pebblebed::Connector.new(nil, connector_options)['checkpoint']

      return @app.call(env) unless request.cors?

      allowed = trusted_origin?(request)

      cors_headers = {'Vary' => 'Origin'}
      if allowed
        cors_headers['Access-Control-Allow-Origin'] = request.origin
        cors_headers['Access-Control-Expose-Headers'] = ''
        cors_headers['Access-Control-Allow-Credentials'] = 'true'
        cors_headers['Vary'] = 'Origin'
      end
      if request.preflight?
        if allowed
          cors_headers['Content-Type'] = 'text/plain'
          cors_headers['Access-Control-Max-Age'] = (60*60).to_s # Tell the browser it can cache the result for this long (in seconds)
          cors_headers['Access-Control-Allow-Headers'] = request.access_control_request_headers if request.access_control_request_headers
          cors_headers['Access-Control-Allow-Methods'] = request.access_control_request_method if request.access_control_request_method
        end
        # Always return empty body when responding to preflighted requests
        [200, cors_headers, []]
      else
        status, headers, body = @app.call(env)
        [status, cors_headers.merge(headers), body]
      end
    end

    private

    def memcached
      @memcached ||= ($memcached || Dalli::Client.new)
    end

    def host_trusts_origin_host?(host, origin_host)

      return @allows_origin_blk.call(host, origin_host) == true if @allows_origin_blk

      begin
        @checkpoint.get("/domains/#{host}/allows/#{origin_host}").allowed == true
      rescue Pebblebed::HttpNotFoundError
        # If we get here, either `host` or `origin_host` is not found in checkpoint
        false
      end
    end

    def cached_host_trusts_origin_host?(host, origin_host)
      memcached.fetch("#{host}_trusts_#{origin_host}", cache_ttl) do
        host_trusts_origin_host?(host, origin_host)
      end
    end

  end

  private
  class CorsRequest < Rack::Request

    # The origin header indicates that this is a CORS request
    # An `origin` is a combination of scheme, host and port, no path data or query string will be provided
    # https://wiki.mozilla.org/Security/Origin#Origin_header_format
    def origin
      env['HTTP_ORIGIN'] || env['HTTP_X_ORIGIN']
    end

    # The host part of the origin header (excluding port)
    def origin_host
      begin
        URI.parse(URI.encode(origin.strip)).host
      rescue URI::InvalidURIError
        origin
      end
    end

    # Is it a CORS request at all?
    def cors?
      !!origin
    end

    # Whether this is a preflight request
    def preflight?
      cors? && options?
    end

    def access_control_request_headers
      env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']
    end

    def access_control_request_method
      env['HTTP_ACCESS_CONTROL_REQUEST_METHOD']
    end

  end

end
