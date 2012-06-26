require "pebbles-cors/version"
require "pebblebed"

module Pebbles
  class Cors
    def initialize(app)
      @app = app
    end

    def call(env)

      request = CorsRequest.new(env)

      unless request.cors? and trusted_domains_for(request.host).include?(request.origin_host)
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

    # Fetch and return the list of trusted domains for a given host
    def trusted_domains_for(host)

      checkpoint = Pebblebed::Connector.new(nil, :host => host)['checkpoint']

      # Find realm of host
      realm = $memcached.fetch("realm_of_domain_#{host}", 60*15) do
        checkpoint.get("/domains/#{host}").domain.realm
      end

      $memcached.fetch("domains_for_realm_#{realm}", 60*15) do
        checkpoint.get("/realms/#{realm}").realm.domains.unwrap
      end
    end
  end

  private
  class CorsRequest < Rack::Request

    # The origin header indicates that this is a CORS request
    # An `origin` is a combination of scheme, host and port, no path data or query string will be provided
    # https://wiki.mozilla.org/Security/Origin#Origin_header_format
    def origin
      @origin ||= env['HTTP_ORIGIN']
      @origin ||= env['HTTP_X_ORIGIN']
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
