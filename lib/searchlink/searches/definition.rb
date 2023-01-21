module SL
  class DefinitionSearch
    class << self
      def settings
        {
          trigger: 'def(?:ine)?',
          searches: [
            ['def', 'Dictionary Definition'],
            ['define', nil]
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        # title, definition, definition_link, wiki_link = zero_click(search_terms)
        # if search_type == 'def' && definition_link != ''
        #   url = definition_link
        #   title = definition.gsub(/'+/,"'")
        # elsif wiki_link != ''
        #   url = wiki_link
        #   title = "Wikipedia: #{title}"
        # end
        fix = SL.spell(search_terms)

        if fix && search_terms.downcase != fix.downcase
          add_error('Spelling', "Spelling altered for '#{search_terms}' to '#{fix}'")
          search_terms = fix
          link_text = fix
        end

        url, title = define(search_terms)

        url ? [url, title, link_text] : [false, false, link_text]
      end

      def define(terms)
        # DDG API is returning "test" results every time
        # url = URI.parse("http://api.duckduckgo.com/?q=!def+#{ERB::Util.url_encode(terms)}&format=json&no_redirect=1&no_html=1&skip_disambig=1")
        # res = Net::HTTP.get_response(url).body
        # res = res.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9

        # result = JSON.parse(res)

        # if result
        #   wiki_link = result['Redirect'] || false
        #   title = terms

        #   if !wiki_link.empty? && !title.empty?
        #     return [wiki_link, title]
        #   end
        # end

        def_url = "https://www.wordnik.com/words/#{ERB::Util.url_encode(terms)}"
        body = `/usr/bin/curl -sSL '#{def_url}'`
        if body =~ /id="define"/
          first_definition = body.match(%r{(?mi)(?:id="define"[\s\S]*?<li>)([\s\S]*?)</li>})[1]
          parts = first_definition.match(%r{<abbr title="partOfSpeech">(.*?)</abbr> (.*?)$})
          return [def_url, "(#{parts[1]}) #{parts[2]}".gsub(/ *<\/?.*?> /, '')]
        end

        false
      rescue StandardError
        false
      end
    end

    SL::Searches.register 'definition', :search, self
  end
end
