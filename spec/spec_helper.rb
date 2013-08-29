if ENV['simplecov']
  require 'simplecov'
  SimpleCov.start do
    add_filter 'spec'
  end
end
require 'rubygems'
require 'rspec'
require 'rspec/mocks'
require 'rspec/autorun'
