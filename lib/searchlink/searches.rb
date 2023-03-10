module SL
  module Searches
    class << self
      def plugins
        @plugins ||= {}
      end

      def load_searches
        Dir.glob(File.join(File.dirname(__FILE__), 'searches', '*.rb')).sort.each { |f| require f }
      end

      #
      # Register a plugin with the plugin manager
      #
      # @param [String, Array] title title or array of titles
      # @param [Symbol] type plugin type (:search)
      # @param [Class] klass class that handles plugin actions. Search plugins 
      #                must have a #settings and a #search method
      #
      def register(title, type, klass)
        Array(title).each { |t| register_plugin(t, type, klass) }
      end

      def description_for_search(search_type)
        description = "#{search_type} search"
        plugins[:search].each do |_, plugin|
          s = plugin[:searches].select { |s| s[0] == search_type }
          unless s.empty?
            description = s[0][1]
            break
          end
        end
        description
      end

      #
      # Output an HTML table of available searches
      #
      # @return [String] Table HTML
      #
      def available_searches_html
        searches = plugins[:search]
                   .flat_map { |_, plugin| plugin[:searches] }
                   .reject { |s| s[1].nil? }
                   .sort_by { |s| s[0] }
        out = ['<table id="searches">',
               '<thead><td>Shortcut</td><td>Search Type</td></thead>',
               '<tbody>']
        searches.each { |s| out << "<tr><td><code>!#{s[0]}</code></td><td>#{s[1]}</td></tr>" }
        out.concat(['</tbody>', '</table>']).join("\n")
      end

      #
      # Aligned list of available searches
      #
      # @return [String] Aligned list of searches
      #
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
      end

      def valid_search?(term)
        valid = false
        valid = true if term =~ /^(#{valid_searches.join('|')})$/
        valid = true if SL.config['custom_site_searches'].keys.include? term
        # SL.notify("Invalid search#{did_you_mean(term)}", term) unless valid
        valid
      end

      def register_plugin(title, type, klass)
        raise StandardError, "Plugin #{title} has no settings method" unless klass.respond_to? :settings

        settings = klass.settings

        raise StandardError, "Plugin #{title} has no search method" unless klass.respond_to? :search

        plugins[type] ||= {}
        plugins[type][title] = {
          trigger: settings.fetch(:trigger, title).normalize_trigger,
          searches: settings[:searches],
          class: klass
        }
      end

      def load_custom
        plugins_folder = File.expand_path('~/.local/searchlink/plugins')
        return unless File.directory?(plugins_folder)

        Dir.glob(File.join(plugins_folder, '**/*.rb')).sort.each do |plugin|
          require plugin
        end
      end

      def do_search(search_type, search_terms, link_text, timeout: SL.config['timeout'])
        plugins[:search].each do |_title, plugin|
          if search_type =~ /^#{plugin[:trigger]}$/
            search = proc { plugin[:class].search(search_type, search_terms, link_text) }
            return SL::Util.search_with_timeout(search, timeout)
          end
        end
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

# import
require_relative 'searches/hook'

# import
require_relative 'searches/lastfm'

# import
require_relative 'searches/pinboard'

# import
require_relative 'searches/social'

# import
require_relative 'searches/software'

# import
require_relative 'searches/spelling'

# import
require_relative 'searches/spotlight'

# import
require_relative 'searches/tmdb'

# import
require_relative 'searches/twitter'

# import
require_relative 'searches/wikipedia'

# import
require_relative 'searches/youtube'

# import
require_relative 'searches/stackoverflow'
