# frozen_string_literal: true

require "spec_helper"

# https://github.com/thoiberg/cli-test
describe "Flags" do
  include CliTest

  it "returns result with title" do
    execute_script("bin/searchlink", use_bundler: true, stdin_data: "[%](!tmdbt legends of tomorrow ++t)")
    expect(last_execution).to be_successful
    expected = %("DC's Legends of Tomorrow")
    expect(last_execution.stdout).to match(/#{Regexp.escape(expected)}/)
  end

  it "returns result without title" do
    execute_script("bin/searchlink", use_bundler: true, stdin_data: "[%](!tmdbt legends of tomorrow --t)")
    expect(last_execution).to be_successful
    expected = %("DC's Legends of Tomorrow")
    expect(last_execution.stdout).not_to match(/#{Regexp.escape(expected)}/)
  end

  it "performs validation" do
    execute_script("bin/searchlink", use_bundler: true, stdin_data: "[falafal fruff](!btt ++v)")
    expect(last_execution).to be_successful
    expected = "No results"
    expect(last_execution.stdout).to match(/#{Regexp.escape(expected)}/)
  end

  it "skips validation" do
    execute_script("bin/searchlink", use_bundler: true, stdin_data: "[falafal fruff](!btt --v)")
    expect(last_execution).to be_successful
    expected = "No results"
    expect(last_execution.stdout).not_to match(/#{Regexp.escape(expected)}/)
  end
end
