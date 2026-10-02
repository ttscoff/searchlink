# frozen_string_literal: true

module SL
  # Search a Linkding instance.
  #
  # Linkding authenticates with an API token and lists bookmarks at
  # GET /api/bookmarks/. The q parameter uses the same search syntax as the
  # Linkding UI (words, "phrases", #tags, and/or/not). Results are ranked
  # the same way as Pinboard: an exact title or tag match wins, then an exact
  # match in the description or notes, then the newest partial match.
  class LinkdingSearch
    PAGE_SIZE = 100
    MAX_PAGES = 10

    class << self
      def settings
        {
          trigger: "(ld|ding)",
          searches: [
            [%w[ld ding], "Linkding Bookmark Search"]
          ],
          config: [
            {
              description: "Linkding server URL, for example https://links.example.com",
              key: "linkding_server",
              value: "''",
              required: true
            },
            {
              description: "Linkding API token.\nCreate one under Settings, Integrations on your Linkding server.",
              key: "linkding_api_key",
              value: "''",
              required: true
            }
          ]
        }
      end

      # Search Linkding bookmarks.
      #
      # Begin the query with ' to require an exact phrase. Quoted phrases,
      # #tags, and and/or/not are passed through to Linkding.
      #
      # @return [Array, false] [url, title, link_text] or false when nothing matches
      def search(_, search_terms, link_text)
        unless server
          SL.add_error("Missing Linkding server",
                       "Add your server URL to the configuration (linkding_server: https://YOUR_SERVER)")
          return false
        end

        unless api_key
          SL.add_error("Missing Linkding API token",
                       "Create a token under Settings, Integrations and add it to the configuration (linkding_api_key: YOURKEY)")
          return false
        end

        query, exact = normalize_query(search_terms)
        bookmarks = search_bookmarks(query)
        return false if bookmarks.nil? || bookmarks.empty?

        best = best_bookmark(bookmarks, query, exact: exact)
        return false unless best

        [best["url"], bookmark_title(best), link_text]
      end

      def server
        value = configured_value("linkding_server")
        return nil unless value

        value.sub(%r{/+\z}, "").sub(%r{/api\z}i, "")
      end

      def api_key
        configured_value("linkding_api_key")
      end

      private

      def configured_value(key)
        value = SL.config[key].to_s.strip
        return nil if value.empty? || value == "''"

        value
      end

      # A leading quote forces an exact phrase, matching Pinboard.
      # %22 is accepted because some callers hand in an encoded query.
      def normalize_query(search_terms)
        terms = search_terms.to_s.gsub("%22", '"').strip
        if terms =~ /\A'/
          phrase = terms.gsub(/\A'+|'+\z/, "")
          [%("#{phrase}"), true]
        else
          [terms, false]
        end
      end

      def search_bookmarks(query)
        active = fetch_pages("/api/bookmarks/", query)
        return nil if active.nil?

        archived = fetch_pages("/api/bookmarks/archived/", query)
        return nil if archived.nil?

        active + archived
      end

      # Page with our own offset. Linkding's next URL can point at an
      # internal hostname, so it is only used as a "more results" flag.
      def fetch_pages(path, query)
        bookmarks = []
        offset = 0

        MAX_PAGES.times do
          json = get_json(path, query, offset)
          return nil if json.nil?

          page = Array(json["results"])
          bookmarks.concat(page)
          offset += PAGE_SIZE
          break if page.empty? || json["next"].nil? || bookmarks.size >= json["count"].to_i
        end

        bookmarks
      end

      def get_json(path, query, offset)
        url = "#{server}#{path}?q=#{query.url_encode}&limit=#{PAGE_SIZE}&offset=#{offset}&sort=added_desc"
        res = Curl::Json.new(url, headers: { "Authorization" => "Token #{api_key}" })
        return json_error(res) unless res&.code.to_s == "200" && res.json.is_a?(Hash)

        res.json
      rescue StandardError
        SL.add_error("Linkding request failed", "Could not search #{server}")
        nil
      end

      def json_error(res)
        detail = res&.json.is_a?(Hash) ? res.json["detail"] : nil
        SL.add_error("Linkding request failed", detail || "Could not search #{server}")
        nil
      end

      def best_bookmark(bookmarks, query, exact:)
        terms = query.gsub(/\A["']+|["']+\z/, "")
        matches = bookmarks.filter_map { |bm| score_bookmark(bm, terms, exact: exact) }
        return nil if matches.empty? && exact

        picked = matches.max_by { |match| [match[:score], match[:date]] }
        picked ? picked[:bookmark] : bookmarks.max_by { |bm| bm["date_added"].to_s }
      end

      def score_bookmark(bookmark, terms, exact:)
        title_tags = bookmark_text(bookmark, "title", "tag_names")
        full_text = bookmark_text(bookmark, "title", "description", "notes", "tag_names", "url")

        if exact
          return nil unless full_text.matches_exact(terms)

          return { score: 14.0, date: bookmark["date_added"].to_s, bookmark: bookmark }
        end

        score = if title_tags.matches_exact(terms)
                  14.0
                elsif full_text.matches_exact(terms)
                  13.0
                elsif full_text.matches_any(terms)
                  full_text.matches_score(terms)
                else
                  0
                end
        return nil unless score.positive?

        { score: score, date: bookmark["date_added"].to_s, bookmark: bookmark }
      end

      def bookmark_text(bookmark, *fields)
        fields.map { |field| field_text(bookmark[field]) }.join(" ")
      end

      def field_text(value)
        value.is_a?(Array) ? value.join(" ") : value.to_s
      end

      def bookmark_title(bookmark)
        title = bookmark["title"].to_s.strip
        title.empty? ? bookmark["url"] : title
      end
    end

    SL::Searches.register "linkding", :search, self
  end
end
