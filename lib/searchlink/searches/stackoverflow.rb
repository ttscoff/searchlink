module SL
  # Stack Overflow search
  class StackOverflowSearch
    class << self
      def settings
        {
          trigger: 'soa?',
          searches: [
            ['so', 'StackOverflow Search'],
            ['soa', 'StackOverflow Accepted Answer']
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        url, title, link_text = SL.ddg("site:stackoverflow.com #{search_terms}", link_text)
        link_text = title if link_text == '' && !SL.titleize

        if search_type =~ /a$/
          body = `curl -SsL #{url}`.strip
          m = body.match(/id="(?<id>answer-\d+)"[^>]+accepted-answer/)
          url = "#{url}##{m['id']}" if m
        end

        [url, title, link_text]
      end
    end

    SL::Searches.register 'stackoverflow', :search, self
  end
end
