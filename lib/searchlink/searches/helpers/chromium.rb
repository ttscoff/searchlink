# frozen_string_literal: true

##
## Chromium (Chrome, Arc, Brave, Edge) search methods
##
module SL
  # Chromium history search
  class HistorySearch
    class << self
      ## Search Arc history
      ##
      ## @param      term  The search term
      ##
      ## @return     [Array] Single bookmark, [url, title, date]
      ##
      def search_arc_history(term)
        # Google history
        history_file = File.expand_path("~/Library/Application Support/Arc/User Data/Default/History")
        if File.exist?(history_file)
          SL.notify("Searching Arc History", term)
          search_chromium_history(history_file, term)
        else
          false
        end
      end

      ## Search Brave history
      ##
      ## @param      term  The search term
      ##
      ## @return     [Array] Single bookmark, [url, title, date]
      ##
      def search_brave_history(term)
        base = File.expand_path("~/Library/Application Support/BraveSoftware/Brave-Browser/")
        profiles = Dir.glob("**/History", base: base)
        profiles.delete_if { |p| p =~ /^Snapshots/ }
        profiles.map! { |f| File.join(base, f) }

        res = false

        profiles.each do |bookmarks|
          next unless File.exist?(bookmarks)

          profile = bookmarks.match(%r{Browser/([^/]+)/})[1]

          SL.notify("Searching Brave History for profile #{profile}", term)
          res = search_chromium_history(bookmarks, term)

          break if res
        end

        res
      end

      ## Search Edge history
      ##
      ## @param      term  The search term
      ##
      ## @return     [Array] Single bookmark, [url, title, date]
      ##
      def search_edge_history(term)
        base = File.expand_path("~/Library/Application Support/Microsoft Edge/")
        profiles = Dir.glob("**/History", base: base)
        profiles.delete_if { |p| p =~ /^Snapshots/ }
        profiles.map! { |f| File.join(base, f) }

        res = false

        profiles.each do |bookmarks|
          next unless File.exist?(bookmarks)

          profile = bookmarks.match(%r{Edge/([^/]+)/})[1]

          SL.notify("Searching Chrome History for profile #{profile}", term)
          res = search_chromium_history(bookmarks, term)

          break if res
        end

        res
      end

      ## Search Chrome history
      ##
      ## @param      term  The search term
      ##
      ## @return     [Array] Single bookmark, [url, title, date]
      ##
      def search_chrome_history(term)
        # Google history
        base = File.expand_path("~/Library/Application Support/Google/Chrome/")
        profiles = Dir.glob("**/History", base: base)
        profiles.delete_if { |p| p =~ /^Snapshots/ }
        profiles.map! { |f| File.join(base, f) }

        # bookmarks_file = File.expand_path('~/Library/Application Support/Google/Chrome/Default/Bookmarks')

        res = false

        profiles.each do |bookmarks|
          next unless File.exist?(bookmarks)

          profile = bookmarks.match(%r{Chrome/([^/]+)/})[1]

          SL.notify("Searching Chrome History for profile #{profile}", term)
          res = search_chromium_history(bookmarks, term)

          break if res
        end

        res
      end

      ##
      ## Generic chromium history search
      ##
      ## @param      history_file  [String] The history file
      ##                           path for the selected
      ##                           browser
      ## @param      term          [String] The search term
      ##
      ## @return     [Array] Single bookmark, [url, title, date]
      ##
      def search_chromium_history(history_file, term)
        tmpfile = "#{history_file}.tmp"
        FileUtils.cp(history_file, tmpfile)

        exact_match = false
        match_phrases = []

        # If search terms start with ''term, only search for exact string matches
        if term =~ /^ *'/
          exact_match = true
          term.gsub!(/(^ *'+|'+ *$)/, "")
        elsif term =~ /%22(.*?)%22/
          match_phrases = term.scan(/%22(\S.*?\S)%22/)
          term.gsub!(/%22(\S.*?\S)%22/, "")
        end

        terms = []
        terms.push("(url NOT LIKE '%search/?%'
                   AND url NOT LIKE '%?q=%'
                   AND url NOT LIKE '%?s=%'
                   AND url NOT LIKE '%www.bing.com%'
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

        query = terms.join(" AND ")
        most_recent = `sqlite3 -json '#{tmpfile}' "select title, url,
        datetime(last_visit_time / 1000000 + (strftime('%s', '1601-01-01')), 'unixepoch') as datum
        from urls where #{query} order by datum desc limit 1 COLLATE NOCASE;"`.strip
        FileUtils.rm_f(tmpfile)
        return false if most_recent.strip.empty?

        bm = JSON.parse(most_recent)[0]

        date = Time.parse(bm["datum"])
        [bm["url"], bm["title"], date]
      end

      ##
      ## Search Arc bookmarks
      ##
      ## @param      term  [String] The search term
      ##
      ## @return     [Array] single bookmark [url, title, date]
      ##
      def search_arc_bookmarks(term)
        bookmarks_file = File.expand_path("~/Library/Application Support/Arc/StorableSidebar.json")

        if File.exist?(bookmarks_file)
          SL.notify("Searching Arc Bookmarks", term)
          return search_arc_json(bookmarks_file, term)
        end

        false
      end

      ##
      ## Search Brave bookmarks
      ##
      ## @param      term  [String] The search term
      ##
      ## @return     [Array] single bookmark [url, title, date]
      ##
      def search_brave_bookmarks(term)
        base = File.expand_path("~/Library/Application Support/BraveSoftware/Brave-Browser/")
        profiles = Dir.glob("**/Bookmarks", base: base)
        profiles.delete_if { |p| p =~ /^Snapshots/ }
        profiles.map! { |f| File.join(base, f) }

        res = false

        profiles.each do |bookmarks|
          next unless File.exist?(bookmarks)

          profile = bookmarks.match(%r{Browser/([^/]+)/})[1]

          SL.notify("Searching Brave Bookmarks for profile #{profile}", term)
          res = search_chromium_bookmarks(bookmarks, term)

          break if res
        end

        res
      end

      ##
      ## Search Ege bookmarks
      ##
      ## @param      term  [String] The search term
      ##
      ## @return     [Array] single bookmark [url, title, date]
      ##
      def search_edge_bookmarks(term)
        base = File.expand_path("~/Library/Application Support/Microsoft Edge")
        profiles = Dir.glob("**/Bookmarks", base: base)
        profiles.delete_if { |p| p =~ /^Snapshots/ }
        profiles.map! { |f| File.join(base, f) }

        res = false

        profiles.each do |bookmarks|
          next unless File.exist?(bookmarks)

          profile = bookmarks.match(%r{Edge/([^/]+)/})[1]

          SL.notify("Searching Edge Bookmarks for profile #{profile}", term)
          res = search_chromium_bookmarks(bookmarks, term)
          break if res
        end

        res
      end

      ##
      ## Search Chrome bookmarks
      ##
      ## @param      term  [String] The search term
      ##
      ## @return     [Array] single bookmark [url, title, date]
      ##
      def search_chrome_bookmarks(term)
        base = File.expand_path("~/Library/Application Support/Google/Chrome/")
        profiles = Dir.glob("**/Bookmarks", base: base)
        profiles.delete_if { |p| p =~ /^Snapshots/ }
        profiles.map! { |f| File.join(base, f) }

        res = false

        profiles.each do |bookmarks|
          next unless File.exist?(bookmarks)

          profile = bookmarks.match(%r{Chrome/([^/]+)/})[1]

          SL.notify("Searching Chrome Bookmarks for profile #{profile}", term)
          res = search_chromium_bookmarks(bookmarks, term)
          break if res
        end

        res
      end

      ##
      ## Search Arc/JSON bookmarks
      ##
      ## @param      bookmarks_file  [String] path to bookmarks file
      ## @param      term            [String] the string to search for
      ##
      ## @return     [Array] single bookmark [url, title, date]
      ##
      def search_arc_json(bookmarks_file, term)
        arc_bookmarks = JSON.parse(IO.read(bookmarks_file))

        exact_match = false
        match_phrases = []

        # If search terms start with ''term, only search for exact string matches
        if term =~ /^ *'/
          exact_match = true
          term.gsub!(/(^ *'+|'+ *$)/, "")
        elsif term =~ /%22(.*?)%22/
          match_phrases = term.scan(/%22(\S.*?\S)%22/)
          term.gsub!(/%22(\S.*?\S)%22/, "")
        end

        if arc_bookmarks
          bookmarks = []
          arc_bookmarks["sidebarSyncState"]["items"].each do |mark|
            next if mark.is_a?(String)

            next unless mark["value"]["childrenIds"].empty?

            next unless mark["value"]["data"]["tab"]

            url = {
              url: mark["value"]["data"]["tab"]["savedURL"],
              saved_title: mark["value"]["data"]["tab"]["savedTitle"],
              title: mark["value"]["title"],
              created: mark["value"]["createdAt"].to_datetime,
              active: mark["value"]["data"]["tab"]["timeLastActiveAt"]&.to_datetime
            }

            score = score_mark(url, term)

            if score > 7
              url[:score] = score
              bookmarks << url
            end
          end

          unless bookmarks.empty?
            if exact_match
              bookmarks.delete_if do |bm|
                !(bm[:url].matches_exact(term) ||
                bm[:title].matches_exact(term) ||
                bm[:saved_title].matches_exact(term))
              end
            end

            if match_phrases
              match_phrases.map! { |phrase| phrase[0] }
              bookmarks.delete_if do |bm|
                matched = true
                match_phrases.each do |phrase|
                  matched = false unless bm[:url].matches_exact(phrase) ||
                                         bm[:title].matches_exact(phrase) ||
                                         bm[:saved_title].matches_exact(phrase)
                end
                !matched
              end
            end

            return false if bookmarks.empty?

            lastest_bookmark = bookmarks.min_by { |u| u[:created] }

            return [lastest_bookmark[:url], lastest_bookmark[:title], lastest_bookmark[:date]]
          end
        end

        false
      end

      ##
      ## Generic chromium bookmark search
      ##
      ## @param      bookmarks_file  [String] The path to
      ##                             bookmarks file for
      ##                             selected browser
      ## @param      term            [String] The term
      ##
      ## @return     [Array] single bookmark [url, title, date]
      ##
      def search_chromium_bookmarks(bookmarks_file, term)
        chrome_bookmarks = JSON.parse(IO.read(bookmarks_file))

        exact_match = false
        match_phrases = []

        # If search terms start with ''term, only search for exact string matches
        if term =~ /^ *'/
          exact_match = true
          term.gsub!(/(^ *'+|'+ *$)/, "")
        elsif term =~ /%22(.*?)%22/
          match_phrases = term.scan(/%22(\S.*?\S)%22/)
          term.gsub!(/%22(\S.*?\S)%22/, "")
        end

        if chrome_bookmarks
          roots = chrome_bookmarks["roots"]

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

      ##
      ## Extract chromium bookmarks from JSON file
      ##
      ## @param      json  [String] The json data
      ## @param      urls  [Array] The gathered urls,
      ##                   appended to recursively
      ## @param      term  [String] The search term
      ##                   (optional)
      ##
      ## @return [Array] array of bookmarks
      ##
      def extract_chrome_bookmarks(json, urls = [], term = "")
        if json.instance_of?(Array)
          json.each { |item| urls = extract_chrome_bookmarks(item, urls, term) }
        elsif json.instance_of?(Hash)
          if json.key? "children"
            urls = extract_chrome_bookmarks(json["children"], urls, term)
          elsif json["type"] == "url"
            date = Time.at(json["date_added"].to_i / 1_000_000 + Time.new(1601, 0o1, 0o1).strftime("%s").to_i)
            url = { url: json["url"], title: json["name"], date: date }
            score = score_mark(url, term)

            if score > 7
              url[:score] = score
              urls << url
            end
          else
            json.each_value { |v| urls = extract_chrome_bookmarks(v, urls, term) }
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

        if mark[:title]&.matches_exact(terms)
          12 + mark[:url].matches_score(terms, start_word: false)
        elsif mark[:url].matches_exact(terms)
          11
        elsif (mark[:title] && mark[:title].matches_score(terms) > 5) ||
              (mark[:saved_title] && mark[:saved_title].matches_score(terms) > 5)

          if mark[:saved_title]
            t = mark[:title]&.matches_score(terms)
            s = mark[:saved_title].matches_score(terms)
            return s if t.nil?

            [t, s].max
          else
            mark[:title]&.matches_score(terms)
          end
        elsif mark[:url].matches_score(terms, start_word: false)
          mark[:url].matches_score(terms, start_word: false)
        else
          0
        end
      end
    end
  end
end
