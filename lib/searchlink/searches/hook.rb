module SL
  class HookSearch
    class << self
      def settings
        {
          trigger: 'hook',
          searches: [
            ['hook', 'Hook Bookmark Search']
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        url, title = search_hook(search_terms)
        [url, title, link_text]
      end

      # Search bookmark paths and addresses. Return array of bookmark hashes.
      def search_hook(search)
        query = search.strip.split(' ').map { |s| %(name contains "#{s}" or path contains "#{s}" or address contains "#{s}") }
        query = query.map { |q| "(#{q})"}.join(' and ')
        path_matches = `osascript <<'APPLESCRIPT'
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

        top_match = path_matches.uniq.first
        return false unless top_match

        [top_match[:url], top_match[:name]]
      end
    end

    SL::Searches.register 'hook', :search, self
  end
end
