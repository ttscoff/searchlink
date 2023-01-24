module SL
  class HistorySearch
    class << self
      def search_arc_history(term)
        # Google history
        history_file = File.expand_path('~/Library/Application Support/Arc/User Data/Default/History')
        if File.exist?(history_file)
          SL.notify('Searching Arc History', term)
          search_chromium_history(history_file, term)
        else
          false
        end
      end

      def search_brave_history(term)
        # Google history
        history_file = File.expand_path('~/Library/Application Support/BraveSoftware/Brave-Browser/Default/History')
        if File.exist?(history_file)
          SL.notify('Searching Brave History', term)
          search_chromium_history(history_file, term)
        else
          false
        end
      end

      def search_edge_history(term)
        # Google history
        history_file = File.expand_path('~/Library/Application Support/Microsoft Edge/Default/History')
        if File.exist?(history_file)
          SL.notify('Searching Edge History', term)
          search_chromium_history(history_file, term)
        else
          false
        end
      end

      def search_chrome_history(term)
        # Google history
        history_file = File.expand_path('~/Library/Application Support/Google/Chrome/Default/History')
        if File.exist?(history_file)
          SL.notify('Searching Chrome History', term)
          search_chromium_history(history_file, term)
        else
          false
        end
      end

      def search_chromium_history(history_file, term)
        tmpfile = "#{history_file}.tmp"
        FileUtils.cp(history_file, tmpfile)

        exact_match = false
        match_phrases = []

        # If search terms start with ''term, only search for exact string matches
        if term =~ /^ *'/
          exact_match = true
          term.gsub!(/(^ *'+|'+ *$)/, '')
        elsif term =~ /%22(.*?)%22/
          match_phrases = term.scan(/%22(\S.*?\S)%22/)
          term.gsub!(/%22(\S.*?\S)%22/, '')
        end

        terms = []
        terms.push("(url NOT LIKE '%search/?%'
                   AND url NOT LIKE '%?q=%'
                   AND url NOT LIKE '%?s=%'
                   AND url NOT LIKE '%duckduckgo.com/?t%')")
        if exact_match
          terms.push("(url LIKE '%#{term.strip.downcase}%' OR title LIKE '%#{term.strip.downcase}%')")
        else
          terms.concat(term.split(/\s+/).map do |t|
            "(url LIKE '%#{t.strip.downcase}%' OR title LIKE '%#{t.strip.downcase}%')"
          end)
          terms.concat(match_phrases.map do |t|
            "(url LIKE '%#{t[0].strip.downcase}%' OR title LIKE '%#{t[0].strip.downcase}%')"
          end)
        end

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
          SL.notify('Searching Brave Bookmarks', term)
          return search_chromium_bookmarks(bookmarks_file, term)
        end

        false
      end

      def search_brave_bookmarks(term)
        bookmarks_file = File.expand_path('~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Bookmarks')

        if File.exist?(bookmarks_file)
          SL.notify('Searching Brave Bookmarks', term)
          return search_chromium_bookmarks(bookmarks_file, term)
        end

        false
      end

      def search_edge_bookmarks(term)
        bookmarks_file = File.expand_path('~/Library/Application Support/Microsoft Edge/Default/Bookmarks')

        if File.exist?(bookmarks_file)
          SL.notify('Searching Edge Bookmarks', term)
          return search_chromium_bookmarks(bookmarks_file, term)
        end

        false
      end

      def search_chrome_bookmarks(term)
        bookmarks_file = File.expand_path('~/Library/Application Support/Google/Chrome/Default/Bookmarks')

        if File.exist?(bookmarks_file)
          SL.notify('Searching Chrome Bookmarks', term)
          return search_chromium_bookmarks(bookmarks_file, term)
        end

        false
      end

      def search_chromium_bookmarks(bookmarks_file, term)
        chrome_bookmarks = JSON.parse(IO.read(bookmarks_file))

        exact_match = false
        match_phrases = []

        # If search terms start with ''term, only search for exact string matches
        if term =~ /^ *'/
          exact_match = true
          term.gsub!(/(^ *'+|'+ *$)/, '')
        elsif term =~ /%22(.*?)%22/
          match_phrases = term.scan(/%22(\S.*?\S)%22/)
          term.gsub!(/%22(\S.*?\S)%22/, '')
        end

        if chrome_bookmarks
          roots = chrome_bookmarks['roots']

          urls = extract_chrome_bookmarks(roots, [], term)

          unless urls.empty?
            urls.delete_if { |bm| !(bm[:url].matches_exact(term) || bm[:title].matches_exact(term)) } if exact_match

            if match_phrases
              match_phrases.map! { |phrase| phrase[0] }
              urls.delete_if do |bm|
                matched = true
                match_phrases.each do |phrase|
                  matched = false unless bm[:url].matches_exact(phrase) || bm[:title].matches_exact(phrase)
                end
                !matched
              end
            end

            return false if urls.empty?

            lastest_bookmark = urls.max_by { |u| u[:score] }

            return [lastest_bookmark[:url], lastest_bookmark[:title], lastest_bookmark[:date]]
          end
        end

        false
      end

      def extract_chrome_bookmarks(json, urls = [], term = '')
        if json.instance_of?(Array)
          json.each { |item| urls = extract_chrome_bookmarks(item, urls, term) }
        elsif json.instance_of?(Hash)
          if json.key? 'children'
            urls = extract_chrome_bookmarks(json['children'], urls, term)
          elsif json['type'] == 'url'
            date = Time.at(json['date_added'].to_i / 1000000 + (Time.new(1601, 01, 01).strftime('%s').to_i))
            url = { url: json['url'], title: json['name'], date: date }
            score = score_mark(url, term)

            if score > 7
              url[:score] = score
              urls << url
            end
          else
            json.each { |_, v| urls = extract_chrome_bookmarks(v, urls, term) }
          end
        else
          return urls
        end
        urls
      end

      ##
      ## Score bookmark for search term matches
      ##
      ## @param      mark   [Hash] The bookmark
      ## @param      terms  [String] The search terms
      ##
      def score_mark(mark, terms)
        return 0 unless mark[:url]

        score = if mark[:title] && mark[:title].matches_exact(terms)
                  12 + mark[:url].matches_score(terms, start_word: false)
                elsif mark[:url].matches_exact(terms)
                  11
                elsif mark[:title] && mark[:title].matches_score(terms) > 5
                  mark[:title].matches_score(terms)
                elsif mark[:url].matches_score(terms, start_word: false)
                  mark[:url].matches_score(terms, start_word: false)
                else
                  0
                end

        score
      end
    end
  end
end
