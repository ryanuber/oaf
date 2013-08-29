require 'simplecov'
require 'coveralls'
Coveralls.wear!
SimpleCov.start do
  add_filter '/spec/'
end
require 'oaf'
require 'ostruct'
require 'tempfile'
