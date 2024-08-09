# frozen_string_literal: true

module SL
  #
  # Hookmark String helpers
  #
  class ::String
    def split_hook
      elements = split(/\|\|/)
      {
        name: elements[0].nil_if_missing,
        url: elements[1].nil_if_missing,
        path: elements[2].nil_if_missing
      }
    end

    def split_hooks
      split(/\^\^/).map(&:split_hook)
    end
  end

  ##
  ## Hookmark Search
  ##
  class HookSearch
    class << self
      def settings
        {
          trigger: 'hook',
          searches: [
            ['hook', 'Hookmark Bookmark Search']
          ]
        }
      end

      # Main search method
      def search(_, search_terms, link_text)
        url, title = search_hook(search_terms)
        [url, title, link_text]
      end

      ##
      ## Run the AppleScript Hookmark query
      ##
      ## @param      query [String]  The query
      ##
      def run_query(query)
        `osascript <<'APPLESCRIPT'
          tell application "Hook"
            set _marks to every bookmark whose #{query}
            set _out to {}
            repeat with _hook in _marks
              set _out to _out & (name of _hook & "||" & address of _hook & "||" & path of _hook)
            end repeat
            set {astid, AppleScript's text item delimiters} to {AppleScript's text item delimiters, "^^"}
            set _output to _out as string
            set AppleScript's text item delimiters to astid
            return _output
          end tell
        APPLESCRIPT`.strip.split_hooks
      end

      # Search bookmark paths and addresses. Return array of bookmark hashes.
      def search_hook(search)
        types = %w[name path address]
        query = search.strip.split(' ').map { |s| types.map { |t| %(#{t} contains "#{s}") }.join(' or ') }
        query = query.map { |q| "(#{q})" }.join(' and ')
        path_matches = run_query(query)

        top_match = path_matches.uniq.first
        return false unless top_match

        [top_match[:url], top_match[:name]]
      end
    end

    SL::Searches.register 'hook', :search, self
  end
end
