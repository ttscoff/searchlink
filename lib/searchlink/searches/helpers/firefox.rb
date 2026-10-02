# frozen_string_literal: true

require "open3"
require "tmpdir"

module SL
  class HistorySearch
    FIREFOX_DIR = "~/Library/Application Support/Firefox"
    ZEN_DIR = "~/Library/Application Support/zen"

    class << self
      # Search Firefox history
      #
      # @param term [String] the search terms
      #
      # @return [Array, false] [url, title, date] or false
      #
      def search_firefox_history(term)
        search_mozilla_history(mozilla_places_db(FIREFOX_DIR), term, "Firefox")
      end

      # Search Firefox bookmarks
      #
      # @param term [String] the search terms
      #
      # @return [Array, false] [url, title, date, score] or false
      #
      def search_firefox_bookmarks(term)
        search_mozilla_bookmarks(mozilla_places_db(FIREFOX_DIR), term, "Firefox")
      end

      # Search Zen history
      #
      # @param term [String] the search terms
      #
      # @return [Array, false] [url, title, date] or false
      #
      def search_zen_history(term)
        search_mozilla_history(mozilla_places_db(ZEN_DIR), term, "Zen")
      end

      # Search Zen bookmarks
      #
      # @param term [String] the search terms
      #
      # @return [Array, false] [url, title, date, score] or false
      #
      def search_zen_bookmarks(term)
        search_mozilla_bookmarks(mozilla_places_db(ZEN_DIR), term, "Zen")
      end

      # Locate the places.sqlite database for a Mozilla-based browser. Profiles
      # listed in profiles.ini are tried in order of preference (install
      # default, then the profile marked Default=1, then any other profile),
      # falling back to a *default-release folder.
      #
      # @param app_dir [String] the browser's Application Support folder
      #
      # @return [String, false] path to places.sqlite or false
      #
      def mozilla_places_db(app_dir)
        base = File.expand_path(app_dir)
        return false unless File.directory?(base)

        ini = File.join(base, "profiles.ini")
        candidates = File.exist?(ini) ? mozilla_ini_profiles(File.read(ini), base) : []
        candidates.concat(Dir.glob(File.join(base, "Profiles", "*default-release")))

        db = candidates.uniq.map { |dir| File.join(dir, "places.sqlite") }.find { |f| File.exist?(f) }
        db || false
      end

      # Parse profiles.ini into a list of profile directories, most preferred first
      #
      # @param contents [String] the contents of profiles.ini
      # @param base [String] the folder containing profiles.ini
      #
      # @return [Array<String>] absolute profile directories
      #
      def mozilla_ini_profiles(contents, base)
        sections = []
        contents.each_line do |line|
          line = line.strip
          if line =~ /^\[(.+)\]$/
            sections << { name: Regexp.last_match(1) }
          elsif line =~ /^([^=]+)=(.*)$/ && sections.any?
            sections.last[Regexp.last_match(1).strip] = Regexp.last_match(2).strip
          end
        end

        absolute = ->(path) { path.start_with?("/") ? path : File.join(base, path) }

        installs = sections.select { |s| s[:name] =~ /^Install/ && s["Default"] }
                           .map { |s| absolute.call(s["Default"]) }
                           .sort_by { |dir| -places_mtime(dir) }
        profiles = sections.select { |s| s[:name] =~ /^Profile/ && s["Path"] }
        defaults, others = profiles.partition { |s| s["Default"] == "1" }

        installs + (defaults + others).map { |s| absolute.call(s["Path"]) }
      end

      # Modification time of a profile's places.sqlite, used to prefer the
      # most recently used install when several share a profiles.ini
      #
      # @param dir [String] the profile directory
      #
      # @return [Float] seconds since epoch, or 0 if there is no database
      #
      def places_mtime(dir)
        db = File.join(dir, "places.sqlite")
        File.exist?(db) ? File.mtime(db).to_f : 0
      end

      # Search the history of a Mozilla-based browser
      #
      # @param src [String, false] path to places.sqlite
      # @param term [String] the search terms
      # @param browser [String] browser name for notifications
      #
      # @return [Array, false] [url, title, date] or false
      #
      def search_mozilla_history(src, term, browser)
        return false unless src && File.exist?(src)

        SL.notify("Searching #{browser} History", term)
        query = mozilla_query(term, "moz_places.url", "moz_places.title")
        mark = query_places(src, "select moz_places.title, moz_places.url,
          datetime(moz_historyvisits.visit_date/1000000, 'unixepoch', 'localtime') as datum
          from moz_places, moz_historyvisits where moz_places.id = moz_historyvisits.place_id
          and #{query} order by datum desc limit 1;")
        return false unless mark

        [mark["url"], mark["title"], Time.parse(mark["datum"])]
      end

      # Search the bookmarks of a Mozilla-based browser
      #
      # @param src [String, false] path to places.sqlite
      # @param term [String] the search terms
      # @param browser [String] browser name for notifications
      #
      # @return [Array, false] [url, title, date, score] or false
      #
      def search_mozilla_bookmarks(src, term, browser)
        return false unless src && File.exist?(src)

        SL.notify("Searching #{browser} Bookmarks", term)
        query = mozilla_query(term, "h.url", "h.title")
        mark = query_places(src, "select h.url, b.title,
          datetime(b.dateAdded/1000000, 'unixepoch', 'localtime') as datum
          FROM moz_places h JOIN moz_bookmarks b ON h.id = b.fk
          where #{query} order by datum desc limit 1;")
        return false unless mark

        score = score_mark({ url: mark["url"], title: mark["title"] }, term)
        [mark["url"], mark["title"], Time.parse(mark["datum"]), score]
      end

      # Build the WHERE clause for a places.sqlite search. Terms starting with
      # a single quote match the exact string, %22-quoted phrases must match
      # as a whole, and all other words must each match the url or title.
      #
      # @param term [String] the search terms
      # @param url_col [String] the url column
      # @param title_col [String] the title column
      #
      # @return [String] SQL conditions
      #
      def mozilla_query(term, url_col, title_col)
        words = []
        case term
        when /^ *'/
          words << term.gsub(/(^ *'+|'+ *$)/, "")
        when /%22(.*?)%22/
          words.concat(term.scan(/%22(\S.*?\S)%22/).flatten)
          words.concat(term.gsub(/%22(\S.*?\S)%22/, "").split(/\s+/))
        else
          words.concat(term.split(/\s+/))
        end

        conditions = ["(#{url_col} NOT LIKE '%search/?%'
                      AND #{url_col} NOT LIKE '%?q=%'
                      AND #{url_col} NOT LIKE '%?s=%'
                      AND #{url_col} NOT LIKE '%duckduckgo.com/?t%')"]
        words.map(&:strip).reject(&:empty?).each do |word|
          like = "'%#{word.downcase.gsub("'", "''")}%'"
          conditions << "(#{url_col} LIKE #{like} OR #{title_col} LIKE #{like})"
        end
        conditions.join(" AND ")
      end

      # Run a query against a copy of places.sqlite, which the browser keeps
      # locked while running. The write-ahead log is copied too so recent
      # visits are included.
      #
      # @param src [String] path to places.sqlite
      # @param sql [String] the query
      #
      # @return [Hash, nil] the first result row
      #
      def query_places(src, sql)
        tmpfile = File.join(Dir.tmpdir, "searchlink-places-#{Process.pid}.sqlite")
        FileUtils.cp(src, tmpfile)
        FileUtils.cp("#{src}-wal", "#{tmpfile}-wal") if File.exist?("#{src}-wal")

        out, status = Open3.capture2("sqlite3", "-json", tmpfile, sql)
        return nil unless status.success? && !out.strip.empty?

        JSON.parse(out).first
      ensure
        FileUtils.rm_f([tmpfile, "#{tmpfile}-wal", "#{tmpfile}-shm"]) if tmpfile
      end
    end
  end
end
