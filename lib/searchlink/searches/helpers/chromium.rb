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
        history_file = File.expand_path('~/Library/Application Support/Microsoft/Edge/Default/History')
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
            lastest_bookmark = urls.max_by { |u| "#{u['url']} #{u['title']}".matches_score(term) }

            return [lastest_bookmark['url'], lastest_bookmark['title'], lastest_bookmark['date']]
          end
        end

        false
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
    end
  end
end
