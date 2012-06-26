# -*- encoding: utf-8 -*-
require File.expand_path('../lib/pebbles-cors/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Bjørge Næss"]
  gem.email         = ["bjoerge@origo.no"]
  gem.description   = %q{Rack middleware for CORS handling in Pebbles}
  gem.summary       = %q{Rack middleware for CORS handling in Pebbles}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "pebbles-cors"
  gem.require_paths = ["lib"]
  gem.version       = Pebbles::Cors::VERSION

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "simplecov"
  gem.add_development_dependency "rack-test"

  gem.add_runtime_dependency "rack"
  gem.add_runtime_dependency "pebblebed"
end
