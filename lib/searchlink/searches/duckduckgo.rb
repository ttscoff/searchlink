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

        prefix = '%5C'

        begin
          cmd = %(/usr/bin/curl -LisS --compressed 'https://lite.duckduckgo.com/lite/?q=#{prefix}#{ERB::Util.url_encode(search_terms)}')

          body = `#{cmd}`
          locs = body.force_encoding('utf-8').scan(/^location: (.*?)$/)
          return false if locs.empty?

          url = locs[-1]

          result = url[0].strip || false
          return false unless result

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

      def zero_click(search_terms, link_text)
        url = URI.parse("http://api.duckduckgo.com/?q=#{ERB::Util.url_encode(search_terms)}&format=json&no_redirect=1&no_html=1&skip_disambig=1")
        res = Net::HTTP.get_response(url).body
        res = res.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9

        result = JSON.parse(res)
        return search('ddg', terms, link_text) unless result

        wiki_link = result['AbstractURL'] || result['Redirect']
        title = result['Heading'] || false

        if !wiki_link.empty? && !title.empty?
          [wiki_link, title, link_text]
        else
          search('ddg', terms, link_text)
        end
      end
    end

    SL::Searches.register 'duckduckgo', :search, self
  end
end

module SL
  class << self
    def ddg(search_terms, link_text)
      SL::Searches.plugins[:search]['duckduckgo'][:class].search('ddg', search_terms, link_text)
    end
  end
end
