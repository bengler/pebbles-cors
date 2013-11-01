# Pebbles::Cors

Rack middleware for [CORS](http://www.w3.org/TR/cors/) handling in Pebbles.

For a request received with an "Origin" header, this middleware will query checkpoint to check whether the given origin
is in the list of domains belonging to the realm of the specified origin (i.e. it is in the list of _trusted domains_).
 
If the given origin is not in the list of _trusted domains_, *no* CORS response headers will be set and the request is
processed normally.

## Requirements

Pebbles::Cors uses memcached to store the list of trusted domains for a given origin. You will therefore need an instance of memcached
running locally. Pebbles::Cors will look for a global variable called `$memcached`, or instantiate a new instance of Dalli::Client if that variable does not exists.

## Installation

Add this line to your application's Gemfile:

    gem 'pebbles-cors'

And then execute:

    $ bundle

## Usage
```ruby
map "/api/my-pebble/v1" do
  use Pebbles::Cors
  
  run MyPebbleV1
end
```

## TODO:

  - Tests are somewhat muddy (but should cover most of it), and need a quick refactor.
  - Make configurable. Things like the `Access-Control-Max-Age` header are hard coded at the moment. Would be nice if 
    this could be configured on a app-basis.

## Example requests:

### Origin is in the list of trusted domains

    curl -I -H "Origin:http://trusted-domain.com" http://pebbles.com/api/pebbelicious/v1/meat/me?session=some-session-id

    HTTP/1.1 200 OK
    Date: Tue, 26 Jun 2012 13:47:11 GMT
    Content-Type: application/json;charset=utf-8
    Connection: keep-alive
    Access-Control-Allow-Origin: http://xdparlor.dev
    Access-Control-Expose-Headers: 
    Access-Control-Allow-Credentials: true

    {"chunky":"bacon"}

### Preflight request

    curl -I -X OPTIONS -H "Origin:http://trusted-domain.dev" http://pebbles.com/api/pebbelicious/v1/meat/me?session=some-session-id

    HTTP/1.1 200 OK
    Date: Tue, 26 Jun 2012 14:19:30 GMT
    Content-Type: text/plain; charset=utf-8
    Status: 200 OK
    Access-Control-Allow-Origin: http://xdparlor.dev
    Access-Control-Expose-Headers: 
    Access-Control-Allow-Credentials: true
    Access-Control-Max-Age: 3600    

### Request from Evil Domain™ where the origin is *not* in list of trusted domains

    curl -I -H "Origin:http://evil-domain.com" http://pebbles.com/api/pebbelicious/v1/meat/me?session=some-session-id

    HTTP/1.1 200 OK
    Date: Tue, 26 Jun 2012 14:04:41 GMT
    Content-Type: application/json;charset=utf-8
    Status: 200 OK

    {"chunky":"bacon"}

Note: The response body is still exposed. This is effectively the same as issuing the same request without the Origin header.
