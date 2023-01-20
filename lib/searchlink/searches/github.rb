module SL
  class SearchLink
    def gist(terms, type)
      terms.strip!
      case terms
      when %r{^(?<id>[a-z0-9]{32})(?:[#/](?<file>(file-)?.*?))?$}
        m = Regexp.last_match
        res = `curl -SsLI 'https://gist.github.com/#{m['id']}'`.strip
        url = res.match(/^location: (.*?)$/)[1].strip
        title = titleize(url)
        if m['file']
          url = "#{url}##{m['file']}"
          title = "#{title}: #{m['file']}"
        end
      when %r{^(?<u>\S+)/(?<id>[a-z0-9]{32})(?:[#/](?<file>(file-)?.*?))?$}
        m = Regexp.last_match
        url = "https://gist.github.com/#{m['u']}/#{m['id']}"
        title = titleize(url)
        if m['file']
          url = "#{url}##{m['file']}"
          title = "#{title}: #{m['file']}"
        end
      when %r{(?<url>https://gist.github.com/(?<user>\w+)/(?<id>[a-z0-9]{32}))(?:[#/](?<file>(file-)?.*?))?$}
        m = Regexp.last_match
        url = m['url']
        title = titleize(url)
        if m['file']
          url = "#{url}##{m['file']}"
          title = "#{title}: #{m['file']}"
        end
      else
        url, title = ddg("site:gist.github.com #{terms}")
      end

      if url =~ %r{https://gist.github.com/(?<user>\w+)/(?<id>[a-z0-9]+?)(?:[#/](?<file>(file-)?.*?))?$}
        m = Regexp.last_match
        user = m['user']
        id = m['id']

        if type =~ /e$/
          url = if m['file']
                  "https://gist.github.com/#{user}/#{id}.js?file=#{m['file'].fix_gist_file}"
                else
                  "https://gist.github.com/#{user}/#{id}.js"
                end

          ['embed', %(<script src="#{url}"></script>)]
        else
          [url, title]
        end
      else
        [false, title]
      end
    end
  end
end
