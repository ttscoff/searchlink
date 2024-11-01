# frozen_string_literal: true

module SL
  class LinkdingSearch
    LINKDING_CACHE = SL::Util.cache_file_for("linkding")

    class << self
      def settings
        {
          trigger: "(ld|ding)",
          searches: [
            [["ld", "ding"], "Linkding Bookmark Search"],
          ],
        }
      end

      def get_json(call)
        curl = TTY::Which.which("curl")
        bookmarks = `#{curl} -SsL -H "Authorization: Token #{SL.config["linkding_api_key"]}" "#{SL.config["linkding_server"]}#{call}"`

        bookmarks = bookmarks.force_encoding("utf-8")
        bookmarks.gsub!(/[^[:ascii:]]/) do |non_ascii|
          non_ascii.force_encoding("utf-8")
            .encode("utf-16be")
            .unpack("H*")[0]
            .gsub(/(....)/, '\u\1')
        end

        bookmarks.gsub!(/[\u{1F600}-\u{1F6FF}]/, "")

        JSON.parse(bookmarks)
      end

      def get_linkding_bookmarks
        curl = TTY::Which.which("curl")
        call = "/api/bookmarks/?limit=8000&format=json"

        json = get_json(call)
        bookmarks = json["results"]
        offset = 0

        while json["next"]
          offset += 8000
          json = get_json(call + "&offset=#{offset}")
          bookmarks.concat(json["results"])
        end

        bookmarks
      end

      def linkding_bookmarks
        bookmarks = get_linkding_bookmarks
        updated = Time.now
        { "update_time" => updated, "bookmarks" => bookmarks }
      end

      def save_linkding_cache(cache)
        cachefile = LINKDING_CACHE

        # file = File.new(cachefile,'w')
        # file = Zlib::GzipWriter.new(File.new(cachefile,'w'))
        begin
          File.open(cachefile, "wb") { |f| f.write(Marshal.dump(cache)) }
        rescue IOError
          SL.add_error("Linkding cache error", "Failed to write stash to disk")
          return false
        end
        true
      end

      def linkding_cache
        refresh_cache = false
        cachefile = LINKDING_CACHE

        if File.exist?(cachefile)
          begin
            # file = IO.read(cachefile) # Zlib::GzipReader.open(cachefile)
            # cache = Marshal.load file
            cache = Marshal.load(File.binread(cachefile))
            # file.close
          rescue IOError # Zlib::GzipFile::Error
            SL.add_error("Error loading linkding cache", "IOError reading #{cachefile}")
            cache = linkding_bookmarks
            save_linkding_cache(cache)
          rescue StandardError
            SL.add_error("Error loading linkding cache", "StandardError reading #{cachefile}")
            cache = linkding_bookmarks
            save_linkding_cache(cache)
          end
          curl = TTY::Which.which("curl")
          updated = get_json("/api/bookmarks/?limit=1&format=json")["results"][0]
          last_bookmark = Time.parse(updated["date_modified"])
          if cache&.key?("update_time")
            last_update = cache["update_time"]
            refresh_cache = true if last_update < last_bookmark
          else
            refresh_cache = true
          end
        else
          refresh_cache = true
        end

        if refresh_cache
          cache = linkding_bookmarks
          save_linkding_cache(cache)
        end

        cache
      end

      # Search pinboard bookmarks
      # Begin query with '' to force exact matching (including description text)
      # Regular matching searches for each word of query and scores the bookmarks
      # exact matches in title get highest score
      # exact matches in description get second highest score
      # other bookmarks are scored based on the number of words that match
      #
      # After sorting by score, bookmarks will be sorted by date and the most recent
      # will be returned
      #
      # Exact matching is case and punctuation insensitive
      def search(_, search_terms, link_text)
        unless SL.config["linkding_server"]
          SL.add_error("Missing Linkding server",
                       "add it to your configuration (linkding_server: https://YOUR_SERVER)")
          return false
        end

        unless SL.config["linkding_api_key"]
          SL.add_error("Missing Linkding API token",
                       "Find your api key at https://your_server/settings/integrations and add it
                        to your configuration (linkding_api_key: YOURKEY)")
          return false
        end

        exact_match = false
        match_phrases = []

        # If search terms start with ''term, only search for exact string matches
        case search_terms
        when /^ *'/
          exact_match = true
          search_terms.gsub!(/(^ *'+|'+ *$)/, "")
        when /%22(.*?)%22/
          match_phrases = search_terms.scan(/%22(\S.*?\S)%22/)
          search_terms.gsub!(/%22(\S.*?\S)%22/, "")
        end

        cache = linkding_cache
        # cache = linkding_bookmarks
        bookmarks = cache["bookmarks"]

        if exact_match
          bookmarks.each do |bm|
            text = [bm["title"], bm["description"], bm["tag_names"].join(" ")].join(" ")

            return [bm["url"], bm["title"]] if text.matches_exact(search_terms)
          end

          return false
        end

        unless match_phrases.empty?
          bookmarks.delete_if do |bm|
            matched = tru
            full_text = [bm["title"], bm["description"], bm["tag_names"].join(" ")].join(" ")
            match_phrases.each do |phrase|
              matched = false unless full_text.matches_exact(phrase)
            end
            !matched
          end
        end

        matches = []
        bookmarks.each do |bm|
          title_tags = [bm["title"], bm["description"]].join(" ")
          full_text = [bm["title"], bm["description"], bm["tag_names"].join(" ")].join(" ")

          score = if title_tags.matches_exact(search_terms)
              14.0
            elsif full_text.matches_exact(search_terms)
              13.0
            elsif full_text.matches_any(search_terms)
              full_text.matches_score(search_terms)
            else
              0
            end

          return [bm["url"], bm["title"]] if score == 14

          next unless score.positive?

          matches.push({
                         score: score,
                         href: bm["url"],
                         title: bm["title"],
                         date: bm["date_added"],
                       })
        end

        return false if matches.empty?

        top = matches.max_by { |bm| [bm[:score], bm[:date]] }

        return false unless top

        [top[:href], top[:title], link_text]
      end
    end

    SL::Searches.register "linkding", :search, self
  end
end
