lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'oaf/version'

Gem::Specification.new do |s|
  s.name          = 'oaf'
  s.version       = Oaf::VERSION
  s.summary       = 'Web app prototyping'
  s.description   = 'Care-free web app prototyping using files and scripts'
  s.authors       = ["Ryan Uber"]
  s.email         = ['ru@ryanuber.com']
  s.files         = %x(git ls-files).split($/)
  s.homepage      = 'https://github.com/ryanuber/oaf'
  s.license       = 'MIT'
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^spec/})
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 1.8'

  s.add_runtime_dependency 'bundler'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'coveralls'
end
