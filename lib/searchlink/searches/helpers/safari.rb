module SL
  class HistorySearch
    class << self
      def search_safari_history(term)
        # Firefox history
        src = File.expand_path('~/Library/Safari/History.db')
        if File.exist?(src)
          SL.notify('Searching Safari History', term)
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
    end
  end
end
