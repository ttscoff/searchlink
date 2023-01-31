module SL
  class WikipediaSearch
    class << self
      def settings
        {
          trigger: 'wiki',
          searches: [
            ['wiki', 'Wikipedia Search']
          ]
        }
      end

      def search(_, search_terms, link_text)
        ## Hack to scrape wikipedia result
        body = `/usr/bin/curl -sSL 'https://en.wikipedia.org/wiki/Special:Search?search=#{search_terms.url_encode}&go=Go'`
        return false unless body

        body = body.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9

        begin
          title = body.match(/"wgTitle":"(.*?)"/)[1]
          url = body.match(/<link rel="canonical" href="(.*?)"/)[1]
        rescue StandardError
          return false
        end

        [url, title, link_text]
      end
    end

    SL::Searches.register 'wikipedia', :search, self
  end
end
