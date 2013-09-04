lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'oaf/version'

Gem::Specification.new do |s|
  files           = Dir.glob('**/*').reject { |f| File.directory? f }
  s.name          = 'oaf'
  s.version       = Oaf::VERSION
  s.summary       = 'Web app prototyping'
  s.description   = 'Care-free web app prototyping using files and scripts'
  s.authors       = 'Ryan Uber'
  s.email         = 'ru@ryanuber.com'
  s.files         = files.grep(/^(lib|bin)/)
  s.homepage      = 'https://github.com/ryanuber/oaf'
  s.license       = 'MIT'
  s.executables   = files.grep(/^bin/) { |f| File.basename f }
  s.test_files    = files.grep(/^spec/)
  s.require_paths = 'lib'

  s.required_ruby_version = '>= 1.8'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'coveralls'
end
