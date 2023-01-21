module SL
  class HistorySearch
    class << self
      def search_firefox_history(term)
        # Firefox history
        base = File.expand_path('~/Library/Application Support/Firefox/Profiles')
        Dir.chdir(base)
        profile = Dir.glob('*default-release')
        return false unless profile

        src = File.join(base, profile[0], 'places.sqlite')

        if File.exist?(src)
          SL.notify('Searching Firefox History', term)
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
          SL.notify('Searching Firefox Bookmarks', term)
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
    end
  end
end
