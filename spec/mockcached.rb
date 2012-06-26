# A naive & minimalistic implementation of Dalli::Client for test purposes
# Doesn't support get_multi
class Mockcached

  def initialize(servers=nil, options={})
    @store = {}
  end

  def get(key, options=nil)
    resp = @store[key]
    (!resp || resp == 'Not found') ? nil : resp
  end

  def fetch(key, ttl=nil, options=nil)
    val = get(key, options)
    if val.nil? && block_given?
      val = yield
      add(key, val, ttl, options)
    end
    val
  end

  def set(key, value, ttl=nil, options=nil)
    raise "Invalid API usage, please require 'dalli/memcache-client' for compatibility, see Upgrade.md" if options == true
    @store[key] = value
  end

  ##
  # Conditionally add a key/value pair, if the key does not already exist
  # on the server.  Returns true if the operation succeeded.
  def add(key, value, ttl=nil, options=nil)
    set(key, value, ttl, options) unless @store.has_key?(key)
  end

  ##
  # Conditionally add a key/value pair, only if the key already exists
  # on the server.  Returns true if the operation succeeded.
  def replace(key, value, ttl=nil, options=nil)
    set(key, value, ttl, options) if @store.has_key?(key)
  end

  def delete(key)
    @store.delete key
  end

  def flush(delay=0)
    @store = {}
  end

end