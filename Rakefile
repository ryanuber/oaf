require 'rubygems'
require 'bundler/setup'
require 'rake/testtask'

Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'

desc "Run all tests"
RSpec::Core::RakeTask.new('spec') do |t|
  t.ruby_opts = ['-I ../lib']
  t.pattern = "spec/*-spec.rb"
  t.rspec_opts = ['-r spec_helper', '--colour', '--format', 'doc', '-b']
  if RUBY_VERSION =~ /^1.8/
    t.rcov = true
    t.rcov_opts = ['-Ispec:lib spec/spec_helper.rb', '--exclude spec,gems', '-T']
  else
    ENV['simplecov'] = 'true'
  end
  t.verbose = true
end

task :default => [:spec]
