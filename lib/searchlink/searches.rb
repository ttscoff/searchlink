module SL
  module Searches
    class << self
      def plugins
        @plugins ||= {}
      end

      def register(title, type, klass)
        if title.is_a?(Array)
          title.each { |t| register(t, type, klass) }
          return
        end

        settings = if klass.respond_to? :settings
                     klass.settings
                   else
                     { trigger: title.normalize_trigger, config: {} }
                   end

        plugins[type] ||= {}
        plugins[type][title] = {
          trigger: settings[:trigger].normalize_trigger || title.normalize_trigger,
          searches: settings[:searches],
          class: klass
        }
      end

      def do_search(search_type, search_terms, link_text)
        url = false
        title = false
        plugins[:search].each do |title, plugin|
          if search_type =~ /^#{plugin[:trigger]}$/
            url, title, link_text = plugin[:class].search(search_type, search_terms, link_text)
            break
          end
        end
        [url, title, link_text]
      end

      def available_searches
        searches = []
        plugins[:search].each { |_, plugin| searches.concat(plugin[:searches].delete_if { |s| s[1].nil? }) }
        out = ''
        searches.each { |s| out += "!#{s[0]}#{s[0].spacer}#{s[1]}\n" }
        out
      end

      def best_search_match(term)
        searches = all_possible_searches.dup
        searches.select { |s| s.matches_score(term, separator: '', start_word: false) > 8 }
      end

      def all_possible_searches
        searches = []
        plugins[:search].each { |_, plugin| plugin[:searches].each { |s| searches.push(s[0]) } }
        searches.concat(SL.config['custom_site_searches'].keys)
      end

      def did_you_mean(term)
        matches = best_search_match(term)
        matches.empty? ? '' : ", did you mean #{matches.map { |m| "!#{m}" }.join(', ')}?"
      end

      def valid_searches
        searches = []
        plugins[:search].each { |_, plugin| searches.push(plugin[:trigger]) }
        searches
        # [
        #   'h(([scfabe])([hb])?)*',
        #   'a',
        #   'imov',
        #   'g',
        #   'ddg',
        #   'z(ero)?',
        #   'wiki',
        #   'def',
        #   'masd?',
        #   'itud?',
        #   'tmdb[amt]?',
        #   's',
        #   '(i|am|l)(art|alb|song|pod)e?',
        #   '@[tfilm]',
        #   'r',
        #   'sp(ell)?',
        #   'pb',
        #   'yte?',
        #   'te',
        #   'file',
        #   'b(l|itly)',
        #   'giste?',
        #   'hook'
        # ]
      end

      def valid_search?(term)
        valid = false
        valid = true if term =~ /^(#{valid_searches.join('|')})$/
        valid = true if SL.config['custom_site_searches'].keys.include? term
        SL.notify("Invalid search#{did_you_mean(term)}", term) unless valid
        valid
      end
    end
  end
end

# import
require_relative 'searches/applemusic'

# import
require_relative 'searches/itunes'

# import
require_relative 'searches/amazon'

# import
require_relative 'searches/bitly'

# import
require_relative 'searches/definition'

# import
require_relative 'searches/duckduckgo'

# import
require_relative 'searches/github'

# import
require_relative 'searches/history'

# # import
# require_relative 'searches/hook'


# # import
# require_relative 'searches/lastfm'

# # import
# require_relative 'searches/pinboard'

# # import
# require_relative 'searches/social'

# # import
# require_relative 'searches/software'

# import
require_relative 'searches/spelling'

# # import
# require_relative 'searches/spotlight'

# # import
# require_relative 'searches/tmdb'

# # import
# require_relative 'searches/twitter'

# # import
# require_relative 'searches/wikipedia'

# # import
# require_relative 'searches/youtube'
