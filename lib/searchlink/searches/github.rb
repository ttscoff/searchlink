module SL
  # GitHub search
  class GitHubSearch
    class << self
      def settings
        {
          trigger: '(?:giste?|ghu?)',
          searches: [
            ['gh', 'GitHub User/Repo Link'],
            ['ghu', 'GitHub User Search'],
            ['gist', 'Gist Search'],
            ['giste', 'Gist Embed']
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        case search_type
        when /^gist/
          url, title, link_text = gist(search_terms, search_type, link_text)
        when /^ghu$/
          url, title, link_text = github_user(search_terms, link_text)
        else
          url, title, link_text = github(search_terms, link_text)
        end

        link_text = title if link_text == '' || link_text == search_terms

        [url, title, link_text]
      end

      def github_search_curl(endpoint, query)
        auth = Secrets::GH_AUTH_TOKEN ? "Authorization: Bearer #{Secrets::GH_AUTH_TOKEN}" : ''

        headers = [
          'Accept: application/vnd.github+json',
          'X-GitHub-Api-Version: 2022-11-28',
          auth
        ]

        url = "https://api.github.com/search/#{endpoint}?q=#{query.url_encode}&per_page=1&page=1&order=desc"

        res = JSON.parse(`curl -SsL #{headers.map { |h| %(-H "#{h}")}.join(' ')} #{url}`)

        if res.key?('total_count') && res['total_count'].positive?
          res['items'][0]
        else
          false
        end
      end

      def user_gists(user, search_terms, page = 1)
        auth = Secrets::GH_AUTH_TOKEN ? "Authorization: Bearer #{Secrets::GH_AUTH_TOKEN}" : ''

        headers = [
          'Accept: application/vnd.github+json',
          'X-GitHub-Api-Version: 2022-11-28',
          auth
        ]

        url = "https://api.github.com/users/#{user}/gists?per_page=100&page=#{page}"

        res = JSON.parse(`curl -SsL #{headers.map { |h| %(-H "#{h}")}.join(' ')} '#{url}'`)

        best = nil
        best = filter_gists(res, search_terms) if res

        if !best && res.count == 100
          SL.notify('Paging', "Getting page #{page + 1} of #{user} gists")
          best = user_gists(user, search_terms, page + 1)
        end

        best
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
          title = SL::URL.get_title(url) if url && title.nil?

          [url, title, link_text]
        else
          SL.notify('Searching GitHub', 'Repo not found, performing search')
          search_github(search_terms, link_text)
        end
      end

      def github_user(search_terms, link_text)
        if search_terms.split(/ /).count > 1
          query = %(#{search_terms} in:name)
          res = github_search_curl('users', query)
        else
          query = %(user:#{search_terms})
          res = github_search_curl('users', query)
          res ||= github_search_curl('users', search_terms)
        end

        if res
          url = res['html_url']
          title = res['login']

          [url, title, link_text]
        else
          [false, false, link_text]
        end
      end

      def search_github(search_terms, link_text)
        search_terms.gsub!(%r{(\S+)/(\S+)}, 'user:\1 \2')
        search_terms.gsub!(/\bu\w*:(\w+)/, 'user:\1')
        search_terms.gsub!(/\bl\w*:(\w+)/, 'language:\1')
        search_terms.gsub!(/\bin?:r\w*/, 'in:readme')
        search_terms.gsub!(/\bin?:t\w*/, 'in:topics')
        search_terms.gsub!(/\bin?:d\w*/, 'in:description')
        search_terms.gsub!(/\bin?:(t(itle)?|n(ame)?)/, 'in:name')
        search_terms.gsub!(/\br:/, 'repo:')

        search_terms += ' in:title' unless search_terms =~ /(in|user|repo):/

        res = github_search_curl('repositories', search_terms)

        return false unless res

        url = res['html_url']
        title = res['description'] || res['full_name']
        [url, title, link_text]
      end

      def search_user_gists(user, search_terms)
        best_gist = user_gists(user, search_terms, 1)

        return false unless best_gist

        best_gist
      end

      def filter_gists(gists, search_terms)
        score = 0
        gists.map! do |g|
          {
            url: g['html_url'],
            description: g['description'],
            files: g['files'].map { |file, info| { filename: file, raw: info['raw_url'] } }
          }
        end
        matches = []
        gists.each do |g|
          if g.key?(:files)
            g[:files].each do |f|
              next unless f[:filename]

              score = f[:filename].matches_score(search_terms.gsub(/[^a-z0-9]/, ' '))

              if score > 5
                url = "#{g[:url]}#file-#{f[:filename].gsub(/\./, '-')}"
                matches << { url: url, title: f[:filename], score: score }
              end
            end
          end

          score = g[:description].nil? ? 0 : g[:description].matches_score(search_terms.gsub(/[^a-z0-9]/, ' '))
          matches << { url: g[:url], title: g[:files][0][:filename], score: score } if score > 5
        end

        return false if matches.empty?

        matches.max_by { |m| m[:score] }
      end

      def gist(terms, type, link_text)
        terms.strip!
        case terms
        # If an id (and optional file) are given, expand it to include username an generate link
        when %r{^(?<id>[a-z0-9]{32}|[0-9]{6,10})(?:[#/](?<file>(?:file-)?.*?))?$}
          m = Regexp.last_match
          res = `curl -SsLI 'https://gist.github.com/#{m['id']}'`.strip
          url = res.match(/^location: (.*?)$/)[1].strip
          title = SL::URL.get_title(url)

          url = "#{url}##{m['file']}" if m['file']
        # If a user an id (an o) are given, convert to a link
        when %r{^(?<u>\w+)/(?<id>[a-z0-9]{32}|[0-9]{6,10})(?:[#/](?<file>(?:file-)?.*?))?$}
          m = Regexp.last_match
          url = "https://gist.github.com/#{m['u']}/#{m['id']}"
          title = SL::URL.get_title(url)

          url = "#{url}##{m['file']}" if m['file']
        # if a full gist URL is given, simply clean it up
        when %r{(?<url>https://gist.github.com/(?:(?<user>\w+)/)?(?<id>[a-z0-9]{32}|[0-9]{6,10}))(?:[#/](?<file>(?:file-)?.*?))?$}
          m = Regexp.last_match
          url = m['url']
          title = SL::URL.get_title(url)

          url = "#{url}##{m['file']}" if m['file']
        # Otherwise do a search of gist.github.com for the keywords
        else
          if terms.split(/ +/).count > 1
            parts = terms.split(/ +/)
            gist = search_user_gists(parts[0], parts[1..].join(' '))

            if gist
              url = gist[:url]
              title = gist[:title]
            else
              url, title, link_text = SL.ddg("site:gist.github.com #{terms}", link_text)
            end
          else
            url, title, link_text = SL.ddg("site:gist.github.com #{terms}", link_text)
          end
        end

        # Assuming we retrieved a full gist URL
        if url =~ %r{https://gist.github.com/(?:(?<user>\w+)/)?(?<id>[a-z0-9]+?)(?:[#/](?<file>(?:file-)?.*?))?$}
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
