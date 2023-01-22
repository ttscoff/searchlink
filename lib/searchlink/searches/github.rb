module SL
  class GitHubSearch
    class << self
      def settings
        {
          trigger: '(?:giste?|gh)',
          searches: [
            ['gh', 'GitHub User/Repo Link'],
            ['gist', 'Gist Search'],
            ['giste', 'Gist Embed']
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        case search_type
        when /^gist/
          url, title = gist(search_terms, search_type, link_text)
        else
          url, title = github(search_terms, link_text)
        end

        [url, title, link_text]
      end

      def github(search_terms, link_text)
        terms = search_terms.split(%r{[ /]+})
        # SL.config['remove_seo'] = false

        url = case terms.count
              when 2
                "https://github.com/#{terms[0]}/#{terms[1]}"
              when 1
                "https://github.com/#{terms[0]}"
              else
                nurl, title, link_text = SL.ddg("site:github.com #{search_terms}", link_text)
                nurl
              end

        if SL::URL.valid_link?(url)
          title = SL::URL.get_title(url) if title.nil?

          [url, title]
        else
          SL.notify('Searching GitHub', 'Repo not found, performing search')
          SL.ddg("site:github.com #{search_terms}", link_text)
        end
      end

      def gist(terms, type, link_text)
        terms.strip!
        case terms
        # If an id (and optional file) are given, expand it to include username an generate link
        when %r{^(?<id>[a-z0-9]{32})(?:[#/](?<file>(?:file-)?.*?))?$}
          m = Regexp.last_match
          res = `curl -SsLI 'https://gist.github.com/#{m['id']}'`.strip
          url = res.match(/^location: (.*?)$/)[1].strip
          title = SL::URL.get_title(url)
          if m['file']
            url = "#{url}##{m['file']}"
            title = "#{title}: #{m['file']}"
          end
        # If a user an id (an o) are given, convert to a link
        when %r{^(?<u>\w+)/(?<id>[a-z0-9]{32})(?:[#/](?<file>(?:file-)?.*?))?$}
          m = Regexp.last_match
          url = "https://gist.github.com/#{m['u']}/#{m['id']}"
          title = SL::URL.get_title(url)
          if m['file']
            url = "#{url}##{m['file']}"
            title = "#{title}: #{m['file']}"
          end
        # if a full gist URL is given, simply clean it up
        when %r{(?<url>https://gist.github.com/(?<user>\w+)/(?<id>[a-z0-9]{32}))(?:[#/](?<file>(?:file-)?.*?))?$}
          m = Regexp.last_match
          url = m['url']
          title = SL::URL.get_title(url)
          if m['file']
            url = "#{url}##{m['file']}"
            title = "#{title}: #{m['file']}"
          end
        # Otherwise do a search of gist.github.com for the keywords
        else
          url, title, link_text = SL.ddg("site:gist.github.com #{terms}", link_text)
        end

        # Assuming we retrieved a full gist URL
        if url =~ %r{https://gist.github.com/(?<user>\w+)/(?<id>[a-z0-9]+?)(?:[#/](?<file>(?:file-)?.*?))?$}
          m = Regexp.last_match
          user = m['user']
          id = m['id']

          # If we're trying to create an embed, convert elements to a JS embed script
          if type =~ /e$/
            url = if m['file']
                    "https://gist.github.com/#{user}/#{id}.js?file=#{m['file'].fix_gist_file}"
                  else
                    "https://gist.github.com/#{user}/#{id}.js"
                  end

            ['embed', %(<script src="#{url}"></script>), link_text]
          else
            [url, title, link_text]
          end
        else
          [false, title, link_text]
        end
      end
    end

    SL::Searches.register 'github', :search, self
  end
end
