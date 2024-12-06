# frozen_string_literal: true

require "spec_helper"

# https://github.com/thoiberg/cli-test
describe "CLI" do
  include CliTest

  describe "completes bare URLs" do
    it "Adds markup and titles, leaving non-bare urls alone" do
      input = <<~EOINPUT
        complete_bare: true

        - http://hibernal.bandcamp.com/
        - https://itunes.apple.com/us/app/steadytune/id670915697?mt=12&ign-mpt=uo%3D4
        - [test](http://bandcamp.com/)
        - <https://itunes.apple.com/us/app/id325946571>
        [ref]: https://itunes.apple.com/au/app/guitartoolkit/id284962368?mt=8
      EOINPUT

      execute_script("bin/searchlink", use_bundler: true, stdin_data: input)
      expect(last_execution).to be_successful

      result_markup = /#{Regexp.escape("[The Strata (Original Soundtrack), by Mark R. Healy]")}/
      result_bare = /#{Regexp.escape("<https://itunes.apple.com/us/app/id325946571>")}/
      expect(last_execution.stdout).to match(result_markup)
      expect(last_execution.stdout).to match(result_bare)
    end
  end
end
