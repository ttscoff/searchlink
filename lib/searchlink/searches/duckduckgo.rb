# frozen_string_literal: true

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
          trigger: '(?:g|ddg|z|ddgimg)',
          searches: [
            ['g', 'Google/DuckDuckGo Search'],
            ['ddg', 'DuckDuckGo Search'],
            ['z', 'DDG Zero Click Search'],
            ['ddgimg', 'Return the first image from the destination page']
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

        # return SL.ddg(search_terms, link_text) if search_type == 'g' && SL::GoogleSearch.api_key?

        terms = "%5C#{search_terms.url_encode}"
        page = Curl::Html.new("https://duckduckgo.com/?q=#{terms}", compressed: true)

        locs = page.meta['refresh'].match(%r{/l/\?uddg=(.*?)$})
        locs = page.body.match(%r{/l/\?uddg=(.*?)'}) if locs.nil?
        locs = page.body.match(/url=(.*?)'/) if locs.nil?

        return false if locs.nil?

        url = locs[1].url_decode.sub(/&rut=\w+/, '')

        result = url.strip.url_decode || false
        return false unless result

        return false if result =~ /internal-search\.duckduckgo\.com/

        # output_url = CGI.unescape(result)
        output_url = result

        output_title = if SL.config['include_titles'] || SL.titleize
                         SL::URL.title(output_url) || ''
                       else
                         ''
                       end

        output_url = SL.first_image(output_url) if search_type =~ /img$/

        [output_url, output_title, link_text]
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
        url = "http://api.duckduckgo.com/?q=#{search_terms.url_encode}&format=json&no_redirect=1&no_html=1&skip_disambig=#{d}"
        result = Curl::Json.new(url, symbolize_names: true).json
        return SL.ddg(terms, link_text) unless result

        wiki_link = result[:AbstractURL] || result[:Redirect]
        title = result[:Heading] || false

        if !wiki_link.empty? && !title.empty?
          [wiki_link, title, link_text]
        elsif disambiguate
          SL.ddg(search_terms, link_text)
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
    # Performs a Google search if API key is available,
    # otherwise defaults to DuckDuckGo
    #
    # @param      search_terms  [String] The search terms
    # @param      link_text     [String] The link text
    # @param      timeout       [Integer] The timeout
    #
    def google(search_terms, link_text = nil, timeout: SL.config['timeout'], image: false)
      if SL::GoogleSearch.api_key?
        s_class = 'google'
        s_type = image ? 'img' : 'gg'
      else
        s_class = 'duckduckgo'
        s_type = image ? 'ddgimg' : 'g'
      end
      search = proc { SL::Searches.plugins[:search][s_class][:class].search(s_type, search_terms, link_text) }
      SL::Util.search_with_timeout(search, timeout)
    end

    # Performs a DuckDuckGo search with the given search terms and link text. If
    # link text is not provided, the first result will be returned. The search
    # will timeout after the given number of seconds.
    #
    # @param      search_terms  [String] The search terms to use
    # @param      link_text     [String] The text of the link to search for
    # @param      timeout       [Integer] The timeout for the search in seconds
    # @param      google        [Boolean] Use Google if API key installed
    # @param      image         [Boolean] Image search
    # @return     [SL::Searches::Result] The search result
    #
    def ddg(search_terms, link_text = nil, timeout: SL.config['timeout'], google: true, image: false)
      if google && SL::GoogleSearch.api_key?
        s_class = 'google'
        s_type = image ? 'img' : 'gg'
      else
        s_class = 'duckduckgo'
        s_type = image ? 'ddgimg' : 'g'
      end

      search = proc { SL::Searches.plugins[:search][s_class][:class].search(s_type, search_terms, link_text) }
      SL::Util.search_with_timeout(search, timeout)
    end

    ##
    ## Perform a site-specific search
    ##
    ## @param      site          [String] The site to search
    ## @param      search_terms  [String] The search terms
    ## @param      link_text     [String] The link text
    ##
    def site_search(site, search_terms, link_text)
      ddg("site:#{site} #{search_terms}", link_text)
    end

    def first_image(url)
      images = Curl::Html.new(url).images
      images.filter { |img| img[:type] == 'img' }.first[:src]
    end
  end
end
