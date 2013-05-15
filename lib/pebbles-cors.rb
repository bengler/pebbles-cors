require "pebbles-cors/version"
require "pebblebed"
require "dalli"

module Pebbles
  class Cors

    attr_accessor :cache_ttl

    def initialize(app, &blk)
      @app = app
      @trusted_domain_fetcher = blk
      @cache_ttl = 60*15 # in seconds
    end

    def trusted_origin?(request)
      # always apply cors-headers to requests coming from localhost
      return true if request.origin_host == 'localhost'

      # Check if the given origin host is allowed to do the request (or a subdomain of a trusted domain)
      cached_host_trusts_origin_host?(request.host, request.origin_host)
    end

    def call(env)
      request = CorsRequest.new(env)

      return @app.call(env) unless request.cors?

      allowed = trusted_origin?(request)

      cors_headers = {}
      if allowed
        cors_headers['Access-Control-Allow-Origin'] = request.origin
        cors_headers['Access-Control-Expose-Headers'] = ""
        cors_headers['Access-Control-Allow-Credentials'] = 'true'
      end
      if request.preflight?
        if allowed
          cors_headers['Content-Type'] = 'text/plain'
          cors_headers['Access-Control-Max-Age'] = (60*60).to_s # Tell the browser it can cache the result for this long (in seconds)
          cors_headers['Access-Control-Allow-Headers'] = request.request_headers if request.request_headers
          cors_headers['Access-Control-Allow-Methods'] = request.request_methods if request.request_methods
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
      if @trusted_domain_fetcher
        @trusted_domain_fetcher.call(host, origin_host)
      else
        begin
          checkpoint = Pebblebed::Connector.new(nil, :host => host)['checkpoint']
          checkpoint.get("/domains/#{host}/trusts/#{origin_host}").allowed == true
        rescue Exception
          false
        end
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
      URI.parse(origin).host
    end

    # Is it a CORS request at all?
    def cors?
      !!origin
    end

    # Whether this is a preflight request
    def preflight?
      cors? && options?
    end

    def request_headers
      env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']
    end

    def request_methods
      env['HTTP_ACCESS_CONTROL_REQUEST_METHODS']
    end

  end

end
