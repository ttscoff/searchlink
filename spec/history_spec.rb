# frozen_string_literal: true

require "spec_helper"

# https://github.com/thoiberg/cli-test
describe "CLI" do
  include CliTest

  return if ENV["SKIP_HISTORY"] == "true"

  # Array of searches and results
  # [[search, expected result],...]
  searches = [
    # history
    # ['* A general history and bookmark search [%](!h brett terpstra forum searchlink)', 'BrettTerpstra.com Forum'],
    # ['* An Arc history search [%](!hah brett terpstra)', %r{https?://brettterpstra.com/}],
    # ['* An Arc bookmark search [%](!hab backbeat podman)', 'https://podman.backbeatmedia.com'],
    # ['* A Brave history search [%](!hbh 2022 hardware)', 'https://brettterpstra.com/2022/12/31/bretts-favorites-2022-hardware'],
    # ['* A Brave bookmark search [%](!hbb backbeat podman)', 'https://podman.backbeatmedia.com'],
    # ['* A Chrome bookmark search [%](!hcb 2022 hardware)', 'https://brettterpstra.com/2022/12/31/bretts-favorites-2022-hardware'],
    # ['* A Chrome history search [%](!hch boss begleri)', 'https://www.aroundsquare.com/collections/begleri/products/micro-boss-begleri-exotics'],
    # ['* An Edge bookmark search [%](!heb 2022 hardware)', 'https://brettterpstra.com/2022/12/31/bretts-favorites-2022-hardware'],
    # ['* An Edge history search [%](!heh brett terpstra)', 'https://brettterpstra.com/'],
    ["* A Firefox bookmark search [%](!hfb 2022 hardware)", "https://brettterpstra.com/2022/12/31/bretts-favorites-2022-hardware"],
    ["* A Firefox history search [markdown exports mindmeister](!hfh)", "https://gist.github.com/ttscoff/cd2a6c17964cccfb6665"],
    ["* A Safari bookmark search [%](!hsb mochajs)", "https://github.com/mochajs/mocha"],
    ["* A Safari history search [%](!hsh oracle template repo)", "oracle/template-repo"],
  ]

  searches.each.with_index do |search, i|
    describe "executes search" do
      context "when given the text '#{search[0]}' (#{i + 1}/#{searches.count})" do
        it "returns #{search[1]}" do
          execute_script("bin/searchlink", use_bundler: true, stdin_data: search[0])
          expect(last_execution).to be_successful

          result = search[1].is_a?(Regexp) ? search[1] : /#{Regexp.escape(search[1])}/
          expect(last_execution.stdout).to match(result)
        end
      end
    end
  end
end
