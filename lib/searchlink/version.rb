module SL
  VERSION = '2.3.30'
end

module SL
  class << self
    def version_check
      cachefile = File.expand_path('~/.searchlink_update_check')
      if File.exist?(cachefile)
        last_check, latest_tag = IO.read(cachefile).strip.split(/\|/)
        last_time = Time.parse(last_check)
      else
        latest_tag = new_version?
        last_time = Time.now
      end

      if last_time + (24 * 60 * 60) < Time.now
        latest_tag = new_version?
        last_time = Time.now
      end

      latest_tag ||= SL::VERSION
      latest = SemVer.new(latest_tag)
      current = SemVer.new(SL::VERSION)
      File.open(cachefile, 'w') { |f| f.puts("#{last_time.strftime('%c')}|#{latest.to_s}")}

      return "SearchLink v#{current.to_s}, #{latest.to_s} available. Run 'update' to download." if latest_tag && current.older_than(latest)

      "SearchLink v#{current.to_s}"
    end

    # Check for a newer version than local copy using GitHub release tag
    #
    # @return false if no new version, or semantic version of latest release
    def new_version?
      cmd = [
        'curl -SsL -H "Accept: application/vnd.github+json"',
        %(-H "Authorization: Bearer #{Secrets::GH_AUTH_TOKEN}"),
        '-H "X-GitHub-Api-Version: 2022-11-28"',
        'https://api.github.com/repos/ttscoff/searchlink/releases/latest'
      ]

      res = `#{cmd.join(' ')}`.strip

      res = res.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9
      result = JSON.parse(res)

      if result
        latest = {}
        current = {}
        latest_tag = result['tag_name']

        return false unless latest_tag

        return false if latest_tag =~ /^#{Regexp.escape(SL::VERSION)}$/

        latest = SemVer.new(latest_tag)
        current = SemVer.new(SL::VERSION)

        return latest_tag if current.older_than(latest)
      else
        warn 'Check for new version failed.'
      end

      false
    end
  end

  class SearchLink
    def update_searchlink
      new_version = SL::new_version?
      if new_version
        folder = File.expand_path('~/Downloads')
        services = File.expand_path('~/Library/Services')
        dl = File.join(folder, 'SearchLink.zip')
        `curl -SsL -o "#{dl}" https://github.com/ttscoff/searchlink/releases/latest/download/SearchLink.zip`
        Dir.chdir(folder)
        `unzip -qo #{dl} -d #{folder}`
        FileUtils.rm(dl)

        ['SearchLink.workflow', 'SearchLink File.workflow', 'Jump to SearchLink Error.workflow'].each do |wflow|
          src = File.join(folder, 'SearchLink Services', wflow)
          dest = File.join(services, wflow)
          FileUtils.cp_r(src, dest)
        end
        add_output("Installed SearchLink #{new_version}")
        FileUtils.rm_rf('SearchLink Services')
      else
        add_output("Already up to date.")
      end
    end
  end
end
