# frozen_string_literal: true

module SL
  class << self
    attr_writer :config, :prev_config

    def config
      @config ||= SL::SearchLink.new({ echo: true })
    end

    def prev_config
      @prev_config ||= {}
    end
  end
end

module SL
  # Main SearchLink class
  class SearchLink
    # Values found in ~/.searchlink will override defaults in
    # this script
    def config_file
      old_style = File.expand_path("~/.searchlink")
      new_style = File.expand_path("~/.config/searchlink/config.yaml")
      if File.exist?(old_style) && !File.exist?(new_style)
        old_style
      else
        FileUtils.mkdir_p(File.dirname(new_style))
        new_style
      end
    end

    def initialize(opt = {})
      SL.printout = opt[:echo] || false
      if File.exist? config_file
        write_new_plugin_config
      else
        default_config = <<~ENDCONFIG
          # set to true to have an HTML comment included detailing any errors
          # Can be disabled per search with `--d`, or enabled with `++d`.
          debug: true
          # set to true to have an HTML comment included reporting results
          report: true

          # use Notification Center to display progress
          notifications: false

          # when running on a file, back up original to *.bak
          backup: true

          # Time limit for searches. Increase if your searches are regularly
          # timing out
          timeout: 15

          # change this to set a specific country for search (default US)
          country_code: US

          # set to true to force inline Markdown links. Can be disabled
          # per search with `--i`, or enabled with `++i`
          inline: false

          # set to true to include a random string in reference titles.
          # Avoids conflicts if you're only running on part of a document
          # or using SearchLink multiple times within a document
          prefix_random: true

          # set to true to add titles to links based on the page title
          # of the search result. Can be disabled per search with `--t`,
          # or enabled with `++t`.
          include_titles: false

          # set to true to attempt to remove SEO elements from page titles,
          # such that "Regular expressions for beginners | Brett Terpstra.com"
          # becomes "Regular expressions for beginners"
          remove_seo: false

          # confirm existence (200) of generated links. Can be disabled
          # per search with `--v`, or enabled with `++v`.
          validate_links: false

          # If the link text is left empty, always insert the page title
          # E.g. [](!g Search Text)
          empty_uses_page_title: false

          # If confirm is true, then a popup dialog will be displayed
          # showing the destination of each found link. Hitting cancel
          # will leave the link unchanged.
          confirm: false

          # To create custom abbreviations for Google Site Searches,
          # add to (or replace) the hash below.
          # "abbreviation" => "site.url",
          # This allows you, for example to use [search term](!bt)
          # as a shortcut to search brettterpstra.com (using a site-specific
          # Google search). Keys in this list can override existing
          # search trigger abbreviations.
          #
          # If a custom search starts with "http" or "/", it becomes
          # a simple replacement. Any instance of "$term" is replaced
          # with a URL-escaped version of your search terms.
          # Use $term1, $term2, etc. to replace in sequence from
          # multiple search terms. No instances of "$term" functions
          # as a simple shortcut. "$term" followed by a "d" lowercases
          # the replacement. Use "$term1d," "$term2d" to downcase
          # sequential replacements (affected individually).
          # Long flags (e.g. --no-validate_links) can be used after
          # any url in the custom searches.
          #
          # Use $terms to slugify all search terms, turning
          # "Markdown Service Tools" into "markdown-service-tools"
          custom_site_searches:
            bt: brettterpstra.com
            btt: https://brettterpstra.com/topic/$term1d
            bts: /search/$term --no-validate_links
            md: www.macdrifter.com
            ms: macstories.net
            dd: www.leancrew.com
            spark: macsparky.com
            man: http://man.cx/$term
            dev: developer.apple.com
            nq: http://nerdquery.com/?media_only=0&query=$term&search=1&category=-1&catid=&type=and&results=50&db=0&prefix=0
            gs: http://scholar.google.com/scholar?btnI&hl=en&q=$term&btnG=&as_sdt=80006

        ENDCONFIG

        default_config = get_plugin_configs(default_config)

        File.open(config_file, "w") do |f|
          f.puts default_config
        end
      end

      config = YAML.load_file(config_file)

      # set to true to have an HTML comment inserted showing any errors
      config["debug"] ||= false

      # set to true to get a verbose report at the end of multi-line processing
      config["report"] ||= false

      config["backup"] = true unless config.key? "backup"

      config["timeout"] ||= 15

      # set to true to force inline links
      config["inline"] ||= false

      # set to true to add titles to links based on site title
      config["include_titles"] ||= false

      # set to true to remove SEO elements from page titles
      config["remove_seo"] ||= false

      # set to true to use page title as link text when empty
      config["empty_uses_page_title"] ||= false

      # change this to set a specific country for search (default US)
      config["country_code"] ||= "US"

      # set to true to include a random string in ref titles
      # allows running SearchLink multiple times w/out conflicts
      config["prefix_random"] = false unless config["prefix_random"]

      config["social_template"] ||= "%service%/%user%"

      # append affiliate link info to iTunes urls, empty quotes for none
      # example:
      # $itunes_affiliate = "&at=10l4tL&ct=searchlink"
      config["itunes_affiliate"] ||= "&at=10l4tL&ct=searchlink"

      # to create Amazon affiliate links, set amazon_partner to your amazon
      # affiliate tag
      #    amazon_partner: "bretttercom-20"
      config["amazon_partner"] ||= ""

      # display a popup dialog confirmation
      config["confirm"] ||= false

      # To create custom abbreviations for Google Site Searches,
      # add to (or replace) the hash below.
      # "abbreviation" => "site.url",
      # This allows you, for example to use [search term](!bt)
      # as a shortcut to search brettterpstra.com. Keys in this
      # hash can override existing search triggers.
      config["custom_site_searches"] ||= {
        "bt" => "brettterpstra.com",
        "imdb" => "imdb.com",
      }

      # confirm existence of links generated from custom search replacements
      config["validate_links"] ||= false

      # use notification center to show progress
      config["notifications"] ||= false

      SL.line_num = nil
      SL.match_column = nil
      SL.match_length = nil
      SL.config = config

      add_plugin_configs(config)
    end

    # Add plugin configurations to config object
    #
    # @param config [Hash] Hash of plugin configurations
    #
    # @note applies configurations to SL.config
    #
    def add_plugin_configs(config)
      SL::Searches.plugins[:search].each_value do |plugin|
        next unless plugin.key?(:config) && !plugin[:config].nil? && !plugin[:config].empty?

        plugin[:config].each do |cfg|
          SL.config[cfg[:key]] = config[cfg[:key]] if config.key?(cfg[:key])
        end
      end
    end

    # Add new keys to config if don't exist
    def write_new_plugin_config
      default_config = IO.read(config_file)
      new_config = ""
      SL::Searches.plugins[:search].each_value do |plugin|
        next unless plugin.key?(:config) && !plugin[:config].nil? && !plugin[:config].empty?

        plugin[:config].each do |cfg|
          next if default_config =~ /^(# *)?#{cfg[:key]}:/

          new_config += get_plugin_config(cfg)
        end
      end

      return if new_config.empty?

      File.open(config_file, "w") { |f| f.puts default_config + new_config }
    end

    #
    # Get plugin configs
    #
    # @param default_config [String] Existing configuration
    #
    # @return [String] default_config with plugin configurations added
    #
    def get_plugin_configs(default_config)
      SL::Searches.plugins[:search].each_value do |plugin|
        next unless plugin.key?(:config) && !plugin[:config].nil? && !plugin[:config].empty?

        plugin[:config].each do |cfg|
          new_config = get_plugin_config(cfg)

          default_config += new_config
        end
      end
      default_config
    end

    #
    # Get a single plugin configuration
    #
    # @param cfg [Hash] Hash of single plugin config
    #
    # @return [String] String representation of config
    #
    def get_plugin_config(cfg)
      key = cfg[:key]
      value = cfg[:value]
      required = cfg[:required]
      description = cfg[:description]
      description = "\n#{description}" if description
      description = description.word_wrap(60, "# ") if description
      key = required ? key : "# #{key}"
      if value.is_a?(Array)
        array_value = "\n"
        value.each do |v|
          array_value += required ? "- #{v.yaml_val}" : "# - #{v.yaml_val}\n"
        end
        value = array_value
      elsif value.is_a?(Hash)
        hash_value = "\n"
        value.each do |k, v|
          hash_value += required ? "  #{k}: #{v.yaml_val}" : "#  #{k}: #{v.yaml_val}"
        end
        value = hash_value
      else
        value = value.yaml_val
      end
      new_config = ""
      new_config += description if description

      new_config + "#{key}: #{value}"
    end

    # Reset configuration
    def restore_prev_config
      @prev_config&.each do |k, v|
        SL.config[k] = v
        $stderr.print "\r\033[0KReset config: #{k} = #{SL.config[k]}\n" unless SILENT
      end
      @prev_config = {}
    end
  end
end
