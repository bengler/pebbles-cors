require './spec/mockcached'
require 'rspec'
require 'pebblebed'

require 'simplecov'

SimpleCov.add_filter 'spec'
SimpleCov.add_filter 'config'
SimpleCov.start

RSpec.configure do |c|
  c.mock_with :rspec
  c.around(:each) do |example|
    #clear_cookies if respond_to?(:clear_cookies)
    $memcached = Mockcached.new
    example.run
  end
end
