# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

describe SL::HistorySearch do
  describe ".history_types_for" do
    it "returns Zen history for !hzh" do
      expect(described_class.history_types_for("hzh")).to eq(%w[zen_history])
    end

    it "returns Zen bookmarks for !hzb" do
      expect(described_class.history_types_for("hzb")).to eq(%w[zen_bookmarks])
    end

    it "returns both Zen types for !hz" do
      expect(described_class.history_types_for("hz")).to contain_exactly("zen_history", "zen_bookmarks")
    end

    it "parses a browser that follows Firefox" do
      expect(described_class.history_types_for("hfhsh")).to eq(%w[firefox_history safari_history])
    end

    it "treats a leading b as Brave" do
      expect(described_class.history_types_for("hbh")).to eq(%w[brave_history])
    end
  end

  describe ".mozilla_places_db" do
    let(:app_dir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(app_dir) }

    def make_profile(name, places: true)
      path = File.join(app_dir, "Profiles", name)
      FileUtils.mkdir_p(path)
      FileUtils.touch(File.join(path, "places.sqlite")) if places
      path
    end

    def write_ini(contents)
      File.write(File.join(app_dir, "profiles.ini"), contents)
    end

    it "uses the install default from profiles.ini" do
      make_profile("ouwuouge.Default Profile", places: false)
      zen = make_profile("x4x6dhih.Default (release)")
      write_ini(<<~INI)
        [Install6ED35B3CA1B5D3AF]
        Default=Profiles/x4x6dhih.Default (release)

        [Profile1]
        Path=Profiles/ouwuouge.Default Profile
        Default=1
      INI

      expect(described_class.mozilla_places_db(app_dir)).to eq(File.join(zen, "places.sqlite"))
    end

    it "prefers the most recently used install default" do
      dev = make_profile("uvzjz141.dev-edition-default")
      release = make_profile("3mvl3gli.default-release")
      File.utime(Time.now - 86_400, Time.now - 86_400, File.join(dev, "places.sqlite"))
      write_ini(<<~INI)
        [Install1F42C145FFDD4120]
        Default=Profiles/uvzjz141.dev-edition-default

        [Install2656FF1E876E9973]
        Default=Profiles/3mvl3gli.default-release
      INI

      expect(described_class.mozilla_places_db(app_dir)).to eq(File.join(release, "places.sqlite"))
    end

    it "skips profiles without places.sqlite" do
      make_profile("aaa.Default Profile", places: false)
      other = make_profile("bbb.Other")
      write_ini(<<~INI)
        [Profile0]
        Path=Profiles/aaa.Default Profile
        Default=1

        [Profile1]
        Path=Profiles/bbb.Other
      INI

      expect(described_class.mozilla_places_db(app_dir)).to eq(File.join(other, "places.sqlite"))
    end

    it "falls back to a *default-release folder without profiles.ini" do
      ff = make_profile("3mvl3gli.default-release")

      expect(described_class.mozilla_places_db(app_dir)).to eq(File.join(ff, "places.sqlite"))
    end

    it "returns false when the browser is not installed" do
      expect(described_class.mozilla_places_db(File.join(app_dir, "missing"))).to be(false)
    end
  end
end
