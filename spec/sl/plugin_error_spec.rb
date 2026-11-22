# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

describe SL::PluginError do
  it "does not exit the process when raised" do
    expect do
      raise described_class.new("boom", plugin: "test.json")
    end.to raise_error(described_class)
  end

  it "includes the plugin name and message" do
    expect do
      raise described_class.new('script "missing.js" not found', plugin: "browser_tabs.json")
    end.to raise_error(described_class, /browser_tabs\.json.*missing\.js/)
  end

  describe "custom script loading" do
    it "skips a broken script plugin instead of aborting" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "broken_tabs.json"), <<~JSON)
          {
            "name": "brokentab",
            "searches": [["btabs", "Broken tabs"]],
            "trigger": "^btabs$",
            "script": "definitely_missing_browser_tabs_#{Process.pid}.js"
          }
        JSON

        expect { SL::Searches.load_custom_scripts(dir) }.not_to raise_error
        expect(SL::Searches.plugins[:search]&.key?("brokentab")).to be_falsey
      end
    end

    it "loads a valid script plugin that points at an executable" do
      Dir.mktmpdir do |dir|
        script = File.join(dir, "ok.sh")
        File.write(script, "#!/bin/sh\necho '{\"url\":\"https://example.com\",\"title\":\"Example\",\"link_text\":\"Example\"}'\n")
        File.chmod(0o755, script)

        File.write(File.join(dir, "ok.json"), <<~JSON)
          {
            "name": "okplugin",
            "searches": [["ok", "OK Plugin"]],
            "trigger": "^ok$",
            "script": "#{script}"
          }
        JSON

        expect { SL::Searches.load_custom_scripts(dir) }.not_to raise_error
        expect(SL::Searches.plugins[:search]).to include("okplugin")
      end
    end
  end
end
