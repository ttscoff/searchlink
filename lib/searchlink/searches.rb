# frozen_string_literal: true

module SL
  # Searches and plugin registration
  module Searches
    class << self
      def plugins
        @plugins ||= {}
      end

      def load_searches
        Dir.glob(File.join(File.dirname(__FILE__), "searches", "*.rb")).sort.each { |f| require f }
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
        plugins[:search].each_value do |plugin|
          search = plugin[:searches].select { |s| s[0].is_a?(Array) ? s[0].include?(search_type) : s[0] == search_type }
          unless search.empty?
            description = search[0][1]
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
                   .sort_by { |s| s[0].is_a?(Array) ? s[0][0] : s[0] }
        out = ['<table id="searches">',
               "<thead><td>Shortcut</td><td>Search Type</td></thead>",
               "<tbody>"]

        searches.each do |s|
          out << "<tr>
          <td>
          <code>!#{s[0].is_a?(Array) ? "#{s[0][0]} (#{s[0][1..].join(',')})" : s[0]}
          </code>
          </td><td>#{s[1]}</td></tr>"
        end
        out.concat(["</tbody>", "</table>"]).join("\n")
      end

      #
      # Aligned list of available searches
      #
      # @return [String] Aligned list of searches
      #
      def available_searches
        searches = []
        plugins[:search].each_value { |plugin| searches.concat(plugin[:searches].delete_if { |s| s[1].nil? }) }
        out = []

        searches.each do |s|
          shortcut = if s[0].is_a?(Array)
                       "#{s[0][0]} (#{s[0][1..].join(',')})"
                     else
                       s[0]
                     end

          out << "!#{shortcut}#{shortcut.spacer}#{s[1]}"
        end
        out.join("\n")
      end

      def best_search_match(term)
        searches = all_possible_searches.dup
        searches.flatten.select { |s| s.matches_score(term, separator: "", start_word: false) > 8 }
      end

      def all_possible_searches
        searches = []
        plugins[:search].each_value { |plugin| plugin[:searches].each { |s| searches.push(s[0]) } }
        searches.concat(SL.config["custom_site_searches"].keys.sort)
      end

      def did_you_mean(term)
        matches = best_search_match(term)
        matches.empty? ? "" : ", did you mean #{matches.map { |m| "!#{m}" }.join(', ')}?"
      end

      def valid_searches
        searches = []
        plugins[:search].each_value { |plugin| searches.push(plugin[:trigger]) }
        searches
      end

      def valid_search?(term)
        valid = false
        valid = true if term =~ /^(#{valid_searches.join('|')})$/
        valid = true if SL.config["custom_site_searches"].keys.include? term
        # SL.notify("Invalid search#{did_you_mean(term)}", term) unless valid
        valid
      end

      def register_plugin(title, type, klass)
        raise PluginError.new("Plugin has no settings method", plugin: title) unless klass.respond_to? :settings

        settings = klass.settings

        raise PluginError.new("Plugin has no search method", plugin: title) unless klass.respond_to? :search

        plugins[type] ||= {}
        plugins[type][title] = {
          trigger: settings.fetch(:trigger, title).normalize_trigger,
          searches: settings[:searches],
          config: settings[:config],
          class: klass
        }
      end

      def load_custom
        plugins_folder = File.expand_path("~/.local/searchlink/plugins")
        new_plugins_folder = File.expand_path("~/.config/searchlink/plugins")

        if File.directory?(plugins_folder) && !File.directory?(new_plugins_folder)
          Dir.glob(File.join(plugins_folder, "**/*.rb")).sort.each do |plugin|
            require plugin
          end

          load_custom_scripts(plugins_folder)
        end

        return unless File.directory?(new_plugins_folder)

        Dir.glob(File.join(new_plugins_folder, "**/*.rb")).sort.each do |plugin|
          require plugin
        end

        load_custom_scripts(new_plugins_folder)
      end

      def load_custom_scripts(plugins_folder)
        Dir.glob(File.join(plugins_folder, "**/*.{json,yml,yaml}")).each do |file|
          ext = File.extname(file).sub(/^\./, "")
          config = IO.read(file)

          cfg = case ext
                when /^y/i
                  YAML.safe_load(config)
                else
                  JSON.parse(config)
                end
          cfg["filename"] = File.basename(file)
          cfg["path"] = file.shorten_path
          SL::ScriptSearch.new(cfg)
        end
      end

      def do_search(search_type, search_terms, link_text, timeout: SL.config["timeout"])
        plugins[:search].each_value do |plugin|
          trigger = plugin[:trigger].gsub(/(^\^|\$$)/, "")
          if search_type =~ /^#{trigger}$/
            search = proc { plugin[:class].search(search_type, search_terms, link_text) }
            return SL::Util.search_with_timeout(search, timeout)
          end
        end
      end
    end
  end
end

# import
require_relative "searches/applemusic"

# import
require_relative "searches/itunes"

# import
require_relative "searches/amazon"

# import
require_relative "searches/bitly"

# import
require_relative "searches/definition"

# import
require_relative "searches/duckduckgo"

# import
require_relative "searches/github"

# import
require_relative "searches/google"

# import
require_relative "searches/history"

# import
require_relative "searches/hook"

# import
require_relative "searches/isgd"

# import
require_relative "searches/lastfm"

# import
require_relative "searches/pinboard"

# import
require_relative "searches/setapp"

# import
require_relative "searches/social"

# import
require_relative "searches/software"

# import
require_relative "searches/spelling"

# import
require_relative "searches/spotlight"

# import
require_relative "searches/tmdb"

# import
require_relative "searches/twitter"

# import
require_relative "searches/wikipedia"

# import
require_relative "searches/youtube"

# import
require_relative "searches/stackoverflow"

# import
require_relative "searches/linkding"
