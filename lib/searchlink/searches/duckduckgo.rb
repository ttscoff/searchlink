module SL
  # DuckDuckGo Search
  class DuckDuckGoSearch
    class << self
      # Returns a hash of settings for the DuckDuckGoSearch
      # class
      #
      # @return     [Hash] settings for the DuckDuckGoSearch
      #             class
      #
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

      # Searches DuckDuckGo for the given search terms
      #
      # @param      search_type   [String] the type of
      #                           search to perform
      # @param      search_terms  [String] the terms to
      #                           search for
      # @param      link_text     [String] the text to
      #                           display for the link
      # @return     [Array] an array containing the URL, title, and
      #             link text
      #
      def search(search_type, search_terms, link_text)
        return zero_click(search_terms, link_text) if search_type =~ /^z$/

        begin
          terms = "%5C#{search_terms.url_encode}"
          body = `/usr/bin/curl -LisS --compressed 'https://duckduckgo.com/?q=#{terms}' 2>/dev/null`

          locs = body.force_encoding('utf-8').match(%r{/l/\?uddg=(.*?)'})

          return false if locs.nil?

          url = locs[1].url_decode.sub(/&rut=\w+/, '')

          result = url.strip.url_decode || false
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

      # Searches DuckDuckGo for the given search terms and
      # returns a zero click result
      #
      # @param      search_terms  [String] the terms to
      #                           search for
      # @param      link_text     [String] the text to
      #                           display for the link
      # @param      disambiguate  [Boolean] whether to
      #                           disambiguate the search
      #
      # @return     [Array] an array containing the URL,
      #             title, and link text
      #
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

    # Registers the DuckDuckGoSearch class with the Searches
    # module
    # @param      name   [String] the name of the search
    # @param      type   [Symbol] the type of search to
    #                    perform
    # @param      klass  [Class] the class to register
    SL::Searches.register 'duckduckgo', :search, self
  end
end

# SL module methods
module SL
  class << self
    # Performs a DuckDuckGo search with the given search
    # terms and link text. If link text is not provided, the
    # first result will be returned. The search will timeout
    # after the given number of seconds.
    #
    # @param      search_terms  [String] The search terms to
    #                           use
    # @param      link_text     [String] The text of the
    #                           link to search for
    # @param      timeout       [Integer] The timeout for
    #                           the search in seconds
    # @return     [SL::Searches::Result] The search result
    #
    def ddg(search_terms, link_text = nil, timeout: SL.config['timeout'])
      search = proc { SL::Searches.plugins[:search]['duckduckgo'][:class].search('ddg', search_terms, link_text) }
      SL::Util.search_with_timeout(search, timeout)
    end
  end
end
