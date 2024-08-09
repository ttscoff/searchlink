# frozen_string_literal: true

module SL
  class HistorySearch
    class << self
      # Search Safari history for terms
      #
      # @param      term  The search term
      #
      def search_safari_history(term)
        # Safari
        src = File.expand_path('~/Library/Safari/History.db')
        if File.exist?(src)
          SL.notify('Searching Safari History', term)

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
                     AND url NOT LIKE '%?q=%' AND url NOT LIKE '%?s=%'
                     AND url NOT LIKE '%/search?%'
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

          cmd = %(sqlite3 -json '#{src}' "select title, url,
          datetime(visit_time/1000000, 'unixepoch', 'localtime') as datum
          from history_visits INNER JOIN history_items ON history_items.id = history_visits.history_item
          where #{query} order by datum desc limit 1 COLLATE NOCASE;")

          most_recent = `#{cmd}`.strip

          return false if most_recent.strip.empty?

          bm = JSON.parse(most_recent)[0]
          date = Time.parse(bm['datum'])
          [bm['url'], bm['title'], date]
        else
          false
        end
      end

      ##
      ## Search Safari bookmarks for relevant search terms
      ##
      ## @param      terms  [String] The search terms
      ##
      ## @return     [Array] [url, title, date]
      ##
      def search_safari_bookmarks(terms)
        data = `plutil -convert xml1 -o - ~/Library/Safari/Bookmarks.plist`.strip
        parent = Plist.parse_xml(data)
        results = get_safari_bookmarks(parent, terms)
        return false if results.empty?

        result = results.max_by { |res| [res[:score], res[:title].length] }

        [result[:url], result[:title], Time.now]
      end

      ##
      ## Score bookmark for search term matches
      ##
      ## @param      mark   [Hash] The bookmark
      ## @param      terms  [String] The search terms
      ##
      def score_bookmark(mark, terms)
        score = if mark[:title].matches_exact(terms)
                  12 + mark[:url].matches_score(terms, start_word: false)
                elsif mark[:url].matches_exact(terms)
                  11
                elsif mark[:title].matches_score(terms) > 5
                  mark[:title].matches_score(terms)
                elsif mark[:url].matches_score(terms, start_word: false)
                  mark[:url].matches_score(terms, start_word: false)
                end

        { url: mark[:url], title: mark[:title], score: score }
      end

      ##
      ## Recursively parse bookmarks hash and score
      ## bookmarks
      ##
      ## @param      parent  [Hash, Array] The parent
      ##                     bookmark item
      ## @param      terms   [String] The search terms
      ##
      ## @return     [Array] array of scored bookmarks
      ##
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
        elsif parent&.key?('Children')
          results.concat(get_safari_bookmarks(parent['Children'], terms))
        end

        results.sort_by { |h| [h[:score], h[:title].length * -1] }.reverse
      end
    end
  end
end
