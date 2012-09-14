require "pebbles-cors/version"
require "pebblebed"
require "dalli"

module Pebbles
  class Cors
    def initialize(app, &blk)
      @app = app
      @trusted_domain_fetcher = blk
    end

    def call(env)

      request = CorsRequest.new(env)

      unless request.cors? and cached_get_trusted_domains_for(request.host).include?(request.origin_host)
        return @app.call(env)
      end

      cors_headers = {
        'Access-Control-Allow-Origin' => request.origin,
        'Access-Control-Expose-Headers' => "",
        'Access-Control-Allow-Credentials' => 'true'
      }

      if request.preflight?
        cors_headers['Content-Type'] = 'text/plain'
        cors_headers['Access-Control-Max-Age'] = (60*60).to_s # Tell the browser it can cache the result for this long (in seconds)
        cors_headers['Access-Control-Allow-Headers'] = request.request_headers if request.request_headers
        cors_headers['Access-Control-Allow-Methods'] = request.request_methods if request.request_methods

        [200, cors_headers, []] # Always return empty body when preflighting
      else
        status, headers, body = @app.call(env)
        [status, cors_headers.merge(headers), body]
      end
    end

    private

    def memcached
      @memcached ||= ($memcached || Dalli::Client.new)
    end

    def get_trusted_domains_for(host)
      if @trusted_domain_fetcher
        @trusted_domain_fetcher.call(host)
      else
        checkpoint = Pebblebed::Connector.new(nil, :host => host)['checkpoint']
        checkpoint.get("/domains/#{host}/realm").realm.domains.unwrap
      end
    end

    # Get the list of trusted domains for a given host/domain
    def cached_get_trusted_domains_for(host)
      memcached.fetch("trusted_domains_for_#{host}", 60*15) do
        get_trusted_domains_for(host)
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

    # The host part of the origin header
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
