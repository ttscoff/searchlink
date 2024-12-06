# frozen_string_literal: true

module SL
  # Spotlight file search
  class SpotlightSearch
    class << self
      def settings
        {
          trigger: "file",
          searches: [
            ["file", "Spotlight Search"]
          ]
        }
      end

      def search(_, search_terms, link_text)
        query = search_terms.gsub(/%22/, '"')
        matches = `mdfind '#{query}' 2>/dev/null`.strip.split(/\n/)
        res = matches.min_by { |r| File.basename(r).length }
        return [false, query, link_text] if res.nil? || res.strip.empty?

        title = File.basename(res)
        link_text = title if link_text.strip.empty? || link_text == search_terms
        ["file://#{res.strip.gsub(/ /, '%20')}", title, link_text]
      end
    end

    SL::Searches.register "spotlight", :search, self
  end
end
