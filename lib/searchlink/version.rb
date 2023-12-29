module SL
  VERSION = '2.3.64'
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
      
      File.open(cachefile, 'w') { |f| f.puts("#{last_time.strftime('%c')}|#{latest.to_s}") }

      return "SearchLink v#{current.to_s}, #{latest.to_s} available. Run 'update' to download." if latest_tag && current.older_than(latest)

      "SearchLink v#{current.to_s}"
    end

    # Check for a newer version than local copy using GitHub release tag
    #
    # @return false if no new version, or semantic version of latest release
    def new_version?
      headers = {
        'Accept' => 'application/vnd.github+json',
        'X-GitHub-Api-Version' => '2022-11-28'
      }
      headers['Authorization'] = "Bearer #{Secrets::GH_AUTH_TOKEN}" if defined? Secrets::GH_AUTH_TOKEN

      url = 'https://api.github.com/repos/ttscoff/searchlink/releases/latest'
      page = Curl::Json.new(url, headers: headers)
      result = page.json

      if result
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

    def update_searchlink
      new_version = SL.new_version?
      if new_version
        folder = File.expand_path('~/Downloads')
        services = File.expand_path('~/Library/Services')
        dl = File.join(folder, 'SearchLink.zip')
        curl = TTY::Which.which('curl')
        `#{curl} -SsL -o "#{dl}" https://github.com/ttscoff/searchlink/releases/latest/download/SearchLink.zip`
        Dir.chdir(folder)
        `unzip -qo #{dl} -d #{folder}`
        FileUtils.rm(dl)

        ['SearchLink', 'SearchLink File', 'Jump to SearchLink Error'].each do |workflow|
          wflow = "#{workflow}.workflow"
          src = File.join(folder, 'SearchLink Services', wflow)
          dest = File.join(services, wflow)
          if File.exist?(src) && File.exist?(dest)
            FileUtils.rm_rf(dest)
            FileUtils.mv(src, dest, force: true)
          end
        end
        add_output("Installed SearchLink #{new_version}")
        FileUtils.rm_rf('SearchLink Services')
      else
        add_output('Already up to date.')
      end
    end
  end
end
