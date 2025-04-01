# frozen_string_literal: true

unless ENV["CI"] == "true"
  # SimpleCov::Formatter::Codecov # For CI
  require "simplecov"
  SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
  SimpleCov.start
end

require "searchlink"
require "cli-test"

RSpec.configure do |c|
  c.expect_with(:rspec) { |e| e.syntax = :expect }
  c.formatter = :documentation

  # c.before(:each) do
  #   allow(FileUtils).to receive(:remove_entry_secure).with(anything)
  #   save_test_file
  # end

  # c.after(:each) do
  #   delete_test_file
  # end
end
