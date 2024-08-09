# frozen_string_literal: true

module SL
  # Dictionary Definition Search
  class DefinitionSearch
    class << self
      # Returns a hash of settings for the search
      #
      # @return     [Hash] the settings for the search
      #
      def settings
        {
          trigger: 'def(?:ine)?',
          searches: [
            ['def', 'Dictionary Definition'],
            ['define', nil]
          ]
        }
      end

      # Searches for a definition of the given terms
      #
      # @param      _             [String] unused
      # @param      search_terms  [String] the terms to
      #                           search for
      # @param      link_text     [String] the text to use
      #                           for the link
      # @return     [Array] the url, title, and link text for the
      #             search
      #
      def search(_, search_terms, link_text)
        fix = SL.spell(search_terms)

        if fix && search_terms.downcase != fix.downcase
          SL.add_error('Spelling', "Spelling altered for '#{search_terms}' to '#{fix}'")
          search_terms = fix
          link_text = fix
        end

        url, title = define(search_terms)

        url ? [url, title, link_text] : [false, false, link_text]
      end

      # Searches for a definition of the given terms
      #
      # @param      terms  [String] the terms to search for
      # @return     [Array] the url and title for the search
      #
      def define(terms)
        def_url = "https://www.wordnik.com/words/#{terms.url_encode}"
        curl = TTY::Which.which('curl')
        body = `#{curl} -sSL '#{def_url}'`
        if body =~ /id="define"/
          first_definition = body.match(%r{(?mi)(?:id="define"[\s\S]*?<li>)([\s\S]*?)</li>})[1]
          parts = first_definition.match(%r{<abbr title="partOfSpeech">(.*?)</abbr> (.*?)$})
          return [def_url, "(#{parts[1]}) #{parts[2]}".gsub(%r{</?.*?>}, '').strip]
        end

        false
      rescue StandardError
        false
      end
    end

    # Registers the search with the SL::Searches module
    SL::Searches.register 'definition', :search, self
  end
end
