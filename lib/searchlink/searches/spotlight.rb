module SL
  class SpotlightSearch
    class << self
      def settings
        {
          trigger: 'file',
          searches: [
            ['file', 'Spotlight Search']
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        query = search_terms
        res = `mdfind '#{query}' 2>/dev/null|head -n 1`
        return [false, query] if res.strip.empty?
        title = File.basename(res)
        link_text = title if link_text.strip.empty? || link_text == search_terms
        ["file://#{res.strip.gsub(/ /, '%20')}", title, link_text]
      end
    end

    SL::Searches.register 'spotlight', :search, self
  end
end
