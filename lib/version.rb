module SL
  VERSION = '2.3.24'
end

def version_check
  latest_tag = new_version?
  return "SearchLink v#{SL::VERSION}, #{latest_tag} available. Run 'update' to download." if latest_tag

  "SearchLink v#{SL::VERSION}"
end

# Check for a newer version than local copy using GitHub release tag
#
# @return false if no new version, or semantic version of latest release
def new_version?
  url = URI.parse('https://api.github.com/repos/ttscoff/searchlink/releases/latest')
  res = Net::HTTP.get_response(url).body
  res = res.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9

  result = JSON.parse(res)

  if result
    latest = {}
    current = {}
    latest_tag = result['tag_name']
    return false if latest_tag =~ /#{SL::VERSION}/

    latest[:maj], latest[:min], latest[:patch] = latest_tag.split(/\./).map(&:to_i)
    current[:maj], current[:min], current[:patch] = SL::VERSION.split(/\./).map(&:to_i)

    behind = if latest[:maj] > current[:maj]
               true
             elsif latest[:min] > current[:min]
               true
             else
               latest[:patch] > current[:patch]
             end

    return latest_tag if behind
  else
    warn 'Check for new version failed.'
  end

  false
end

class SearchLink
  def update_searchlink
    new_version = new_version?
    if new_version
      folder = File.expand_path('~/Downloads')
      services = File.expand_path('~/Library/Services')
      dl = File.join(folder, 'SearchLink.zip')
      `curl -SsL -o "#{dl}" https://github.com/ttscoff/searchlink/releases/latest/download/SearchLink.zip`
      Dir.chdir(folder)
      puts `unzip -qo #{dl} -d #{folder}`
      FileUtils.rm(dl)

      ['SearchLink.workflow', 'SearchLink File.workflow', 'Jump to SearchLink Error.workflow'].each do |wflow|
        src = File.join(folder, 'SearchLink Services', wflow)
        dest = File.join(services, wflow)
        FileUtils.cp_r(src, dest)
      end
      $stderr.print "Installed SearchLink #{new_version}"
      FileUtils.rm_rf('SearchLink Services')
    else
      $stderr.print "Already up to date."
    end
  end
end
