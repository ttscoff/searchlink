module SL
  class SearchLink
    def available_searches
      searches = [
        %w[a Amazon],
        %w[g Google],
        %w[ddg DuckDuckGo],
        %w[yt YouTube],
        ['z', 'DDG Zero-Click Search'],
        %w[wiki Wikipedia],
        ['s', 'Software search (Google)'],
        ['@t', 'Twitter user link'],
        ['@f', 'Facebook user link'],
        ['@l', 'LinkedIn user link'],
        ['@i', 'Instagram user link'],
        ['@m', 'Mastodon user link'],
        ['am', 'Apple Music'],
        ['amart', 'Apple Music Artist'],
        ['amalb', 'Apple Music Album'],
        ['amsong', 'Apple Music Song'],
        ['ampod', 'Apple Music Podcast'],
        ['ipod', 'iTunes podcast'],
        ['isong', 'iTunes song'],
        ['iart', 'iTunes artist'],
        ['ialb', 'iTunes album'],
        ['lsong', 'Last.fm song'],
        ['lart', 'Last.fm artist'],
        ['mas', 'Mac App Store'],
        ['masd', 'Mac App Store developer link'],
        ['itu', 'iTunes App Store'],
        ['itud', 'iTunes App Store developer link'],
        ['imov', 'iTunes Movies'],
        ['def', 'Dictionary definition'],
        %w[hook Hookmarks],
        ['tmdb', 'The Movie Database search'],
        ['tmdba', 'The Movie Database Actor search'],
        ['tmdbm', 'The Movie Database Movie search'],
        ['tmdbt', 'The Movie Database TV search'],
        %w[sp Spelling],
        %w[pb Pinboard],
        ['h', 'Web history'],
        ['hs[hb]', 'Safari [history, bookmarks]'],
        ['hc[hb]', 'Chrome [history, bookmarks]'],
        ['hf[hb]', 'Firefox [history, bookmarks]'],
        ['he[hb]', 'Edge [history, bookmarks]'],
        ['hb[hb]', 'Brave [history, bookmarks]'],
        ['te', 'Twitter embed'],
        ['file', 'Local file:// link (Spotlight)'],
        ['bl', 'Shorten URL with Bit.ly'],
        ['gist', 'GitHub Gist'],
        ['giste', 'GitHub Gist embed']
      ]
      out = ''
      searches.each { |s| out += "!#{s[0]}#{spacer(s[0])}#{s[1]}\n" }
      out
    end

    def best_search_match(term)
      searches = all_possible_searches.dup
      searches.select do |s|
        s.matches_score(term, separator: '', start_word: false) > 8
      end
    end

    def did_you_mean(term)
      matches = best_search_match(term)
      matches.empty? ? '' : ", did you mean #{matches.map { |m| "!#{m}" }.join(', ')}?"
    end

    def all_possible_searches
      %w[
        @f
        @i
        @l
        @m
        @t
        a
        amalb
        amalbe
        amart
        amarte
        ampod
        ampode
        amsong
        amsonge
        bl
        ddg
        def
        file
        g
        gist
        giste
        h
        ha
        hab
        habh
        hah
        hahb
        hb
        hbb
        hbbh
        hbh
        hbhb
        hc
        hcb
        hcbh
        hch
        hchb
        he
        heb
        hebh
        heh
        hehb
        hf
        hfb
        hfbh
        hfh
        hfhb
        hook
        hs
        hsb
        hsbh
        hsh
        hshb
        ialb
        ialbe
        iart
        iarte
        imov
        ipod
        ipode
        isong
        isonge
        itu
        itud
        lalb
        lalbe
        lart
        larte
        lpod
        lpode
        lsong
        lsonge
        mas
        masd
        pb
        r
        s
        sp
        spell
        te
        tmdb
        tmdba
        tmdbm
        tmdbt
        wiki
        yt
        yte
        z
        zero
      ].concat(@cfg['custom_site_searches'].keys)
    end

    def valid_searches
      [
        'h(([scfabe])([hb])?)*',
        'a',
        'imov',
        'g',
        'ddg',
        'z(ero)?',
        'wiki',
        'def',
        'masd?',
        'itud?',
        'tmdb[amt]?',
        's',
        '(i|am|l)(art|alb|song|pod)e?',
        '@[tfilm]',
        'r',
        'sp(ell)?',
        'pb',
        'yte?',
        'te',
        'file',
        'b(l|itly)',
        'giste?',
        'hook'
      ]
    end

    def valid_search?(term)
      valid = false
      valid = true if term =~ /^(#{valid_searches.join('|')})$/
      valid = true if @cfg['custom_site_searches'].keys.include? term
      notify("Invalid search#{did_you_mean(term)}", term) unless valid
      valid
    end

    ### General Search

    def google(terms, define = false)
      uri = URI.parse("http://ajax.googleapis.com/ajax/services/search/web?v=1.0&filter=1&rsz=small&q=#{ERB::Util.url_encode(terms)}")
      req = Net::HTTP::Get.new(uri.request_uri)
      req['Referer'] = 'http://brettterpstra.com'
      res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
      body = if RUBY_VERSION.to_f > 1.9
               res.body.force_encoding('utf-8')
             else
               res.body
             end

      json = JSON.parse(body)
      return ddg(terms, false) unless json['responseData']

      result = json['responseData']['results'][0]
      return false if result.nil?

      output_url = result['unescapedUrl']
      output_title = if define && output_url =~ /dictionary/
                       result['content'].gsub(/<\/?.*?>/, '')
                     else
                       result['titleNoFormatting']
                     end
      [output_url, output_title]
    rescue StandardError
      ddg(terms, false)
    end

    def ddg(terms, type = false)
      prefix = type ? "#{type.sub(/^!?/, '!')} " : '%5C'
      begin
        cmd = %(/usr/bin/curl -LisS --compressed 'https://lite.duckduckgo.com/lite/?q=#{prefix}#{ERB::Util.url_encode(terms)}')
        body = `#{cmd}`
        locs = body.force_encoding('utf-8').scan(/^location: (.*?)$/)
        return false if locs.empty?

        url = locs[-1]

        result = url[0].strip || false
        return false unless result

        # output_url = CGI.unescape(result)
        output_url = result

        output_title = if @cfg['include_titles'] || @titleize
                         titleize(output_url) || ''
                       else
                         ''
                       end
        [output_url, output_title]
      end
    end

    ### Browsers

    def search_arc_history(term)
      # Google history
      history_file = File.expand_path('~/Library/Application Support/Arc/User Data/Default/History')
      if File.exist?(history_file)
        notify('Searching Arc History', term)
        search_chromium_history(history_file, term)
      else
        false
      end
    end

    def search_brave_history(term)
      # Google history
      history_file = File.expand_path('~/Library/Application Support/BraveSoftware/Brave-Browser/Default/History')
      if File.exist?(history_file)
        notify('Searching Brave History', term)
        search_chromium_history(history_file, term)
      else
        false
      end
    end

    def search_edge_history(term)
      # Google history
      history_file = File.expand_path('~/Library/Application Support/Microsoft/Edge/Default/History')
      if File.exist?(history_file)
        notify('Searching Edge History', term)
        search_chromium_history(history_file, term)
      else
        false
      end
    end

    def search_chrome_history(term)
      # Google history
      history_file = File.expand_path('~/Library/Application Support/Google/Chrome/Default/History')
      if File.exist?(history_file)
        notify('Searching Chrome History', term)
        search_chromium_history(history_file, term)
      else
        false
      end
    end

    def search_chromium_history(history_file, term)
      tmpfile = "#{history_file}.tmp"
      FileUtils.cp(history_file, tmpfile)

      terms = []
      terms.push("(url NOT LIKE '%search/?%'
                 AND url NOT LIKE '%?q=%'
                 AND url NOT LIKE '%?s=%'
                 AND url NOT LIKE '%duckduckgo.com/?t%')")
      terms.concat(term.split(/\s+/).map do |t|
        "(url LIKE '%#{t.strip.downcase}%'
        OR title LIKE '%#{t.strip.downcase}%')"
      end)
      query = terms.join(' AND ')
      most_recent = `sqlite3 -json '#{tmpfile}' "select title, url,
      datetime(last_visit_time / 1000000 + (strftime('%s', '1601-01-01')), 'unixepoch') as datum
      from urls where #{query} order by datum desc limit 1 COLLATE NOCASE;"`.strip
      FileUtils.rm_f(tmpfile)
      return false if most_recent.strip.empty?

      bm = JSON.parse(most_recent)[0]

      date = Time.parse(bm['datum'])
      [bm['url'], bm['title'], date]
    end

    def search_arc_bookmarks(term)
      bookmarks_file = File.expand_path('~/Library/Application Support/Arc/User Data/Default/Bookmarks')

      if File.exist?(bookmarks_file)
        notify('Searching Brave Bookmarks', term)
        return search_chromium_bookmarks(bookmarks_file, term)
      end

      false
    end

    def search_brave_bookmarks(term)
      bookmarks_file = File.expand_path('~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Bookmarks')

      if File.exist?(bookmarks_file)
        notify('Searching Brave Bookmarks', term)
        return search_chromium_bookmarks(bookmarks_file, term)
      end

      false
    end

    def search_edge_bookmarks(term)
      bookmarks_file = File.expand_path('~/Library/Application Support/Microsoft/Edge/Default/Bookmarks')

      if File.exist?(bookmarks_file)
        notify('Searching Edge Bookmarks', term)
        return search_chromium_bookmarks(bookmarks_file, term)
      end

      false
    end

    def search_chrome_bookmarks(term)
      bookmarks_file = File.expand_path('~/Library/Application Support/Google/Chrome/Default/Bookmarks')

      if File.exist?(bookmarks_file)
        notify('Searching Chrome Bookmarks', term)
        return search_chromium_bookmarks(bookmarks_file, term)
      end

      false
    end

    def search_chromium_bookmarks(bookmarks_file, term)
      chrome_bookmarks = JSON.parse(IO.read(bookmarks_file))

      if chrome_bookmarks
        terms = term.split(/\s+/)
        roots = chrome_bookmarks['roots']
        urls = extract_chrome_bookmarks(roots)
        urls.sort_by! { |bookmark| bookmark['date_added'] }
        urls.select do |u|
          found = true
          terms.each { |t| found = false unless u['url'] =~ /#{t}/i || u['title'] =~ /#{t}/i }
          found
        end
        unless urls.empty?
          lastest_bookmark = urls[-1]
          return [lastest_bookmark['url'], lastest_bookmark['title'], lastest_bookmark['date']]
        end
      end

      false
    end

    def search_firefox_history(term)
      # Firefox history
      base = File.expand_path('~/Library/Application Support/Firefox/Profiles')
      Dir.chdir(base)
      profile = Dir.glob('*default-release')
      return false unless profile

      src = File.join(base, profile[0], 'places.sqlite')

      if File.exist?(src)
        notify('Searching Firefox History', term)
        tmpfile = "#{src}.tmp"
        FileUtils.cp(src, tmpfile)

        terms = []
        terms.push("(moz_places.url NOT LIKE '%search/?%'
                   AND moz_places.url NOT LIKE '%?q=%'
                   AND moz_places.url NOT LIKE '%?s=%'
                   AND moz_places.url NOT LIKE '%duckduckgo.com/?t%')")
        terms.concat(term.split(/\s+/).map do |t|
          "(moz_places.url LIKE '%#{t.strip.downcase}%' OR moz_places.title LIKE '%#{t.strip.downcase}%')"
        end)
        query = terms.join(' AND ')
        most_recent = `sqlite3 -json '#{tmpfile}' "select moz_places.title, moz_places.url,
        datetime(moz_historyvisits.visit_date/1000000, 'unixepoch', 'localtime') as datum
        from moz_places, moz_historyvisits where moz_places.id = moz_historyvisits.place_id
        and #{query} order by datum desc limit 1 COLLATE NOCASE;"`.strip
        FileUtils.rm_f(tmpfile)

        return false if most_recent.strip.empty?

        bm = JSON.parse(most_recent)[0]

        date = Time.parse(bm['datum'])
        [bm['url'], bm['title'], date]
      else
        false
      end
    end

    def search_firefox_bookmarks(term)
      # Firefox history
      base = File.expand_path('~/Library/Application Support/Firefox/Profiles')
      Dir.chdir(base)
      profile = Dir.glob('*default-release')
      return false unless profile

      src = File.join(base, profile[0], 'places.sqlite')

      if File.exist?(src)
        notify('Searching Firefox Bookmarks', term)
        tmpfile = "#{src}.tmp"
        FileUtils.cp(src, tmpfile)

        terms = []
        terms.push("(h.url NOT LIKE '%search/?%'
                   AND h.url NOT LIKE '%?q=%'
                   AND h.url NOT LIKE '%?s=%'
                   AND h.url NOT LIKE '%duckduckgo.com/?t%')")
        terms.concat(term.split(/\s+/).map do |t|
          "(h.url LIKE '%#{t.strip.downcase}%' OR b.title LIKE '%#{t.strip.downcase}%')"
        end)

        query = terms.join(' AND ')

        most_recent = `sqlite3 -json '#{tmpfile}' "select h.url, b.title,
        datetime(b.dateAdded/1000000, 'unixepoch', 'localtime') as datum
        FROM moz_places h JOIN moz_bookmarks b ON h.id = b.fk
        where #{query} order by datum desc limit 1 COLLATE NOCASE;"`.strip
        FileUtils.rm_f(tmpfile)

        return false if most_recent.strip.empty?

        bm = JSON.parse(most_recent)[0]

        date = Time.parse(bm['datum'])
        [bm['url'], bm['title'], date]
      else
        false
      end
    end

    def search_safari_history(term)
      # Firefox history
      src = File.expand_path('~/Library/Safari/History.db')
      if File.exist?(src)
        notify('Searching Safari History', term)
        tmpfile = "#{src}.tmp"
        FileUtils.cp(src, tmpfile)

        terms = []
        terms.push("(url NOT LIKE '%search/?%'
                   AND url NOT LIKE '%?q=%' AND url NOT LIKE '%?s=%'
                   AND url NOT LIKE '%duckduckgo.com/?t%')")
        terms.concat(term.split(/\s+/).map do |t|
          "(url LIKE '%#{t.strip.downcase}%' OR title LIKE '%#{t.strip.downcase}%')"
        end)
        query = terms.join(' AND ')
        most_recent = `sqlite3 -json '#{tmpfile}' "select title, url,
        datetime(visit_time/1000000, 'unixepoch', 'localtime') as datum
        from history_visits INNER JOIN history_items ON history_items.id = history_visits.history_item
        where #{query} order by datum desc limit 1 COLLATE NOCASE;"`.strip
        FileUtils.rm_f(tmpfile)

        return false if most_recent.strip.empty?

        bm = JSON.parse(most_recent)[0]
        date = Time.parse(bm['datum'])
        [bm['url'], bm['title'], date]
      else
        false
      end
    end

    def search_safari_bookmarks(terms)
      result = nil

      data = `plutil -convert xml1 -o - ~/Library/Safari/Bookmarks.plist`.strip
      parent = Plist::parse_xml(data)
      result = get_safari_bookmarks(parent, terms).first
      return false if result.nil?

      [result[:url], result[:title], Time.now]
    end

    def score_bookmark(mark, terms)
      score = if mark[:title].matches_exact(terms)
                15
              elsif mark[:url].matches_exact(terms)
                11
              elsif mark[:title].matches_score(terms) > 5
                mark[:title].matches_score(terms)
              elsif mark[:url].matches_score(terms, start_word: false)
                mark[:url].matches_score(terms, start_word: false)
              end

      { url: mark[:url], title: mark[:title], score: score }
    end

    def extract_chrome_bookmarks(json, urls = [])
      if json.instance_of?(Array)
        json.each { |item| urls = extract_chrome_bookmarks(item, urls) }
      elsif json.instance_of?(Hash)
        if json.key? 'children'
          urls = extract_chrome_bookmarks(json['children'], urls)
        elsif json['type'] == 'url'
          date = Time.at(json['date_added'].to_i / 1000000 + (Time.new(1601, 01, 01).strftime('%s').to_i))
          urls << { 'url' => json['url'], 'title' => json['name'], 'date' => date }
        else
          json.each { |_, v| urls = extract_chrome_bookmarks(v, urls) }
        end
      else
        return urls
      end
      urls
    end

    def get_safari_bookmarks(parent, terms)
      results = []
      if parent.is_a?(Array)
        parent.each do |c|
          if c.is_a?(Hash)
            if c.key?('Children')
              results.concat(get_safari_bookmarks(c['Children'], terms))
            elsif c.key?('URIDictionary')
              title = c['URIDictionary']['title']
              url = c['URLString']
              scored = score_bookmark({ url: url, title: title }, terms)
              results.push(scored) if scored[:score] > 7
            end
          end
        end
      else
        results.concat(get_safari_bookmarks(parent['Children'], terms))
      end
      results.sort_by { |h| [h[:score], h[:title].length * -1] }.reverse

    end

    def search_history(term,types = [])
      if types.empty?
        return false unless @cfg['history_types']

        types = @cfg['history_types']
      end

      results = []

      if !types.empty?
        types.each do |type|
          url, title, date = send("search_#{type}", term)

          results << { 'url' => url, 'title' => title, 'date' => date } if url
        end

        if results.empty?
          false
        else
          out = results.sort_by! { |r| r['date'] }.last
          [out['url'], out['title']]
        end
      else
        false
      end
    end

    ### Local files

    def spotlight(query)
      res = `mdfind '#{query}' 2>/dev/null|head -n 1`
      return [false, query] if res.strip.empty?

      ["file://#{res.strip.gsub(/ /, '%20')}", File.basename(res)]
    end

    # Search bookmark paths and addresses. Return array of bookmark hashes.
    def search_hook(search)
      query = search.strip.split(' ').map { |s| %(name contains "#{s}" or path contains "#{s}" or address contains "#{s}") }
      query = query.map { |q| "(#{q})"}.join(' and ')
      path_matches = `osascript <<'APPLESCRIPT'
        tell application "Hook"
          set _marks to every bookmark whose #{query}
          set _out to {}
          repeat with _hook in _marks
            set _out to _out & (name of _hook & "||" & address of _hook & "||" & path of _hook)
          end repeat
          set {astid, AppleScript's text item delimiters} to {AppleScript's text item delimiters, "^^"}
          set _output to _out as string
          set AppleScript's text item delimiters to astid
          return _output
        end tell
      APPLESCRIPT`.strip.split_hooks

      top_match = path_matches.uniq.first
      return false unless top_match

      [top_match[:url], top_match[:name]]
    end

    ### Movies/TV

    def tmdb(search_type, terms)
      type = case search_type
             when /t$/
               'tv'
             when /m$/
               'movie'
             when /a$/
               'person'
             else
               'multi'
             end
      body = `/usr/bin/curl -sSL 'https://api.themoviedb.org/3/search/#{type}?query=#{ERB::Util.url_encode(terms)}&api_key=2bd76548656d92517f14d64766e87a02'`
      data = JSON.parse(body)
      if data.key?('results') && data['results'].count.positive?
        res = data['results'][0]
        type = res['media_type'] if type == 'multi'
        id = res['id']
        url = "https://www.themoviedb.org/#{type}/#{id}"
        title = res['name']
        title ||= res['title']
        title ||= terms
      else
        url, title = ddg("site:imdb.com #{terms}")

        return false unless url
      end

      [url, title]
    end

    ### Reference

    def define(terms)
      # DDG API is returning "test" results every time
      # url = URI.parse("http://api.duckduckgo.com/?q=!def+#{ERB::Util.url_encode(terms)}&format=json&no_redirect=1&no_html=1&skip_disambig=1")
      # res = Net::HTTP.get_response(url).body
      # res = res.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9

      # result = JSON.parse(res)

      # if result
      #   wiki_link = result['Redirect'] || false
      #   title = terms

      #   if !wiki_link.empty? && !title.empty?
      #     return [wiki_link, title]
      #   end
      # end

      def_url = "https://www.wordnik.com/words/#{ERB::Util.url_encode(terms)}"
      body = `/usr/bin/curl -sSL '#{def_url}'`
      if body =~ /id="define"/
        first_definition = body.match(%r{(?mi)(?:id="define"[\s\S]*?<li>)([\s\S]*?)</li>})[1]
        parts = first_definition.match(%r{<abbr title="partOfSpeech">(.*?)</abbr> (.*?)$})
        return [def_url, "(#{parts[1]}) #{parts[2]}".gsub(/ *<\/?.*?> /, '')]
      end

      false
    rescue StandardError
      false
    end

    def spell(phrase)
      aspell = if File.exist?('/usr/local/bin/aspell')
                 '/usr/local/bin/aspell'
               elsif File.exist?('/opt/homebrew/bin/aspell')
                 '/opt/homebrew/bin/aspell'
               end

      if aspell.nil?
        add_error('Missing aspell', 'Install aspell in to allow spelling corrections')
        return false
      end

      words = phrase.split(/\b/)
      output = ''
      words.each do |w|
        if w =~ /[A-Za-z]+/
          spell_res = `echo "#{w}" | #{aspell} --sug-mode=bad-spellers -C pipe | head -n 2 | tail -n 1`
          if spell_res.strip == "\*"
            output += w
          else
            spell_res.sub!(/.*?: /, '')
            results = spell_res.split(/, /).delete_if { |word| phrase =~ /^[a-z]/ && word =~ /[A-Z]/ }
            output += results[0]
          end
        else
          output += w
        end
      end
      output
    end

    def wiki(terms)
      ## Hack to scrape wikipedia result
      body = `/usr/bin/curl -sSL 'https://en.wikipedia.org/wiki/Special:Search?search=#{ERB::Util.url_encode(terms)}&go=Go'`
      return unless body

      body = body.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9

      begin
        title = body.match(/"wgTitle":"(.*?)"/)[1]
        url = body.match(/<link rel="canonical" href="(.*?)"/)[1]
      rescue StandardError
        return false
      end

      [url, title]

      ## Removed because Ruby 2.0 does not like https connection to wikipedia without using gems?
      # uri = URI.parse("https://en.wikipedia.org/w/api.php?action=query&format=json&prop=info&inprop=url&titles=#{CGI.escape(terms)}")
      # req = Net::HTTP::Get.new(uri.path)
      # req['Referer'] = "http://brettterpstra.com"
      # req['User-Agent'] = "SearchLink (http://brettterpstra.com)"

      # res = Net::HTTP.start(uri.host, uri.port,
      #   :use_ssl => true,
      #   :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
      #     https.request(req)
      #   end

      # if RUBY_VERSION.to_f > 1.9
      #   body = res.body.force_encoding('utf-8')
      # else
      #   body = res.body
      # end

      # result = JSON.parse(body)

      # if result
      #   result['query']['pages'].each do |page,info|
      #     unless info.key? "missing"
      #       return [info['fullurl'],info['title']]
      #     end
      #   end
      # end
      # return false
    end

    def gist(terms, type)
      terms.strip!
      if terms =~ %r{^(?<id>[a-z0-9]{32})(?:[#/](?<file>(file-)?.*?))?$}
        m = Regexp.last_match
        res = `curl -SsLI 'https://gist.github.com/#{m['id']}'`.strip
        url = res.match(/^location: (.*?)$/)[1].strip
        title = titleize(url)
        if m['file']
          url = "#{url}##{m['file']}"
          title = "#{title}: #{m['file']}"
        end
      elsif terms =~ %r{^(?<u>\S+)/(?<id>[a-z0-9]{32})(?:[#/](?<file>(file-)?.*?))?$}
        m = Regexp.last_match
        url = "https://gist.github.com/#{m['u']}/#{m['id']}"
        title = titleize(url)
        if m['file']
          url = "#{url}##{m['file']}"
          title = "#{title}: #{m['file']}"
        end
      elsif terms = %r{(?<url>https://gist.github.com/(?<user>\w+)/(?<id>[a-z0-9]{32}))(?:[#/](?<file>(file-)?.*?))?$}
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

    def zero_click(terms)
      url = URI.parse("http://api.duckduckgo.com/?q=#{ERB::Util.url_encode(terms)}&format=json&no_redirect=1&no_html=1&skip_disambig=1")
      res = Net::HTTP.get_response(url).body
      res = res.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9

      result = JSON.parse(res)
      return ddg(terms) unless result

      wiki_link = result['AbstractURL'] || result['Redirect']
      title = result['Heading'] || false

      if !wiki_link.empty? && !title.empty?
        [wiki_link, title]
      else
        ddg(terms)
      end
    end

    ### Music

    # Search apple music
    # terms => search terms (unescaped)
    # media => music, podcast
    # entity => optional: artist, song, album, podcast
    # returns {:type=>,:id=>,:url=>,:title}
    def applemusic(terms, media = 'music', entity = '')
      aff = @cfg['itunes_affiliate']
      output = {}

      url = URI.parse("http://itunes.apple.com/search?term=#{ERB::Util.url_encode(terms)}&country=#{@cfg['country_code']}&media=#{media}&entity=#{entity}")
      res = Net::HTTP.get_response(url).body
      res = res.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9
      res.gsub!(/(?mi)[\x00-\x08\x0B-\x0C\x0E-\x1F]/, '')
      json = JSON.parse(res)
      return false unless json['resultCount']&.positive?

      result = json['results'][0]

      case result['wrapperType']
      when 'track'
        if result['kind'] == 'podcast'
          output[:type] = 'podcast'
          output[:id] = result['collectionId']
          output[:url] = result['collectionViewUrl'].to_am + aff
          output[:title] = result['collectionName']
        else
          output[:type] = 'song'
          output[:album] = result['collectionId']
          output[:id] = result['trackId']
          output[:url] = result['trackViewUrl'].to_am + aff
          output[:title] = "#{result['trackName']} by #{result['artistName']}"
        end
      when 'collection'
        output[:type] = 'album'
        output[:id] = result['collectionId']
        output[:url] = result['collectionViewUrl'].to_am + aff
        output[:title] = "#{result['collectionName']} by #{result['artistName']}"
      when 'artist'
        output[:type] = 'artist'
        output[:id] = result['artistId']
        output[:url] = result['artistLinkUrl'].to_am + aff
        output[:title] = result['artistName']
      end
      return false if output.empty?

      output
    end

    def itunes(entity, terms, dev, aff = nil)
      aff ||= @cfg['itunes_affiliate']

      url = URI.parse("http://itunes.apple.com/search?term=#{ERB::Util.url_encode(terms)}&country=#{@cfg['country_code']}&entity=#{entity}")
      res = Net::HTTP.get_response(url).body
      res = res.force_encoding('utf-8').encode # if RUBY_VERSION.to_f > 1.9

      begin
        json = JSON.parse(res)
      rescue StandardError => e
        add_error('Invalid response', "Search for #{terms}: (#{e})")
        return false
      end
      return false unless json

      return false unless json['resultCount']&.positive?

      result = json['results'][0]
      case entity
      when /movie/
        # dev parameter probably not necessary in this case
        output_url = result['trackViewUrl']
        output_title = result['trackName']
      when /(mac|iPad)Software/
        output_url = dev && result['sellerUrl'] ? result['sellerUrl'] : result['trackViewUrl']
        output_title = result['trackName']
      when /(musicArtist|song|album)/
        case result['wrapperType']
        when 'track'
          output_url = result['trackViewUrl']
          output_title = "#{result['trackName']} by #{result['artistName']}"
        when 'collection'
          output_url = result['collectionViewUrl']
          output_title = "#{result['collectionName']} by #{result['artistName']}"
        when 'artist'
          output_url = result['artistLinkUrl']
          output_title = result['artistName']
        end
      when /podcast/
        output_url = result['collectionViewUrl']
        output_title = result['collectionName']
      end
      return false unless output_url && output_title

      return [output_url, output_title] if dev

      [output_url + aff, output_title]
    end

    def lastfm(entity, terms)
      url = URI.parse("http://ws.audioscrobbler.com/2.0/?method=#{entity}.search&#{entity}=#{ERB::Util.url_encode(terms)}&api_key=2f3407ec29601f97ca8a18ff580477de&format=json")
      res = Net::HTTP.get_response(url).body
      res = res.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9
      json = JSON.parse(res)
      return false unless json['results']

      begin
        case entity
        when 'track'
          result = json['results']['trackmatches']['track'][0]
          url = result['url']
          title = "#{result['name']} by #{result['artist']}"
        when 'artist'
          result = json['results']['artistmatches']['artist'][0]
          url = result['url']
          title = result['name']
        end
        [url, title]
      rescue StandardError
        false
      end
    end

    ### Twitter

    def twitter_embed(tweet)
      res = `curl -sSL 'https://publish.twitter.com/oembed?url=#{ERB::Util.url_encode(tweet)}'`.strip
      if res
        begin
          json = JSON.parse(res)
          url = 'embed'
          title = json['html']
        rescue StandardError
          add_error('Tweet Error', 'Error retrieving tweet')
          url = false
          title = tweet
        end
      else
        return [false, 'Error retrieving tweet']
      end
      return [url, title]
    end

    ### Misc

    def bitly_shorten(url, title = nil)
      unless @cfg.key?('bitly_access_token') && !@cfg['bitly_access_token'].empty?
        add_error('Bit.ly not configured', 'Missing access token')
        return [false, title]
      end

      domain = @cfg.key?('bitly_domain') ? @cfg['bitly_domain'] : 'bit.ly'
      cmd = [
        %(curl -SsL -H 'Authorization: Bearer #{@cfg['bitly_access_token']}'),
        %(-H 'Content-Type: application/json'),
        '-X POST', %(-d '{ "long_url": "#{url}", "domain": "#{domain}" }'), 'https://api-ssl.bitly.com/v4/shorten'
      ]
      data = JSON.parse(`#{cmd.join(' ')}`.strip)
      link = data['link']
      title ||= @titleize ? titleize(url) : 'Bit.ly Link'
      [link, title]
    end
  end
end
