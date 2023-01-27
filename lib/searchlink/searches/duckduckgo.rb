module SL
  class DuckDuckGoSearch
    class << self
      def settings
        {
          trigger: '(?:g|ddg|z)',
          searches: [
            ['g', 'DuckDuckGo Search'],
            ['ddg', 'DuckDuckGo Search'],
            ['z', 'DDG Zero Click Search']
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        return zero_click(search_terms, link_text) if search_type =~ /^z$/

        begin
          terms = "%5C#{search_terms.url_encode}"
          body = `/usr/bin/curl -LisS --compressed 'https://lite.duckduckgo.com/lite/?q=#{terms}' 2>/dev/null`

          locs = body.force_encoding('utf-8').scan(/^location: (.*?)$/)
          return false if locs.empty?

          url = locs[-1]

          result = url[0].strip || false
          return false unless result

          return false if result =~ /internal-search\.duckduckgo\.com/

          # output_url = CGI.unescape(result)
          output_url = result

          output_title = if SL.config['include_titles'] || SL.titleize
                           SL::URL.get_title(output_url) || ''
                         else
                           ''
                         end

          [output_url, output_title, link_text]
        end
      end

      def zero_click(search_terms, link_text, disambiguate: false)
        search_terms.gsub!(/%22/, '"')
        d = disambiguate ? '0' : '1'
        url = URI.parse("http://api.duckduckgo.com/?q=#{search_terms.url_encode}&format=json&no_redirect=1&no_html=1&skip_disambig=#{d}")
        res = Net::HTTP.get_response(url).body
        res = res.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9

        result = JSON.parse(res)
        return search('ddg', terms, link_text) unless result

        wiki_link = result['AbstractURL'] || result['Redirect']
        title = result['Heading'] || false

        if !wiki_link.empty? && !title.empty?
          [wiki_link, title, link_text]
        elsif disambiguate
          search('ddg', search_terms, link_text)
        else
          zero_click(search_terms, link_text, disambiguate: true)
        end
      end
    end

    SL::Searches.register 'duckduckgo', :search, self
  end
end

# SL module methods
module SL
  class << self
    def ddg(search_terms, link_text = nil, timeout: SL.config['timeout'])
      search = proc { SL::Searches.plugins[:search]['duckduckgo'][:class].search('ddg', search_terms, link_text) }
      SL::Util.search_with_timeout(search, timeout)
    end
  end
end
