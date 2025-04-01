# frozen_string_literal: true

# title: Script plugin
# description: Load custom searches from non-ruby scripts
module SL
  # Script Search
  class ScriptSearch
    def initialize(config)
      @filename = config["filename"]
      @path = config["path"]

      %w[trigger searches name script].each do |key|
        raise PluginError.new(%(configuration missing key "#{key}"), plugin: @filename) unless config.key?(key)
      end

      @trigger = config["trigger"]
      @searches = config["searches"]
      @name = config["name"]
      @script = find_script(config["script"])

      unless File.executable?(@script)
        raise PluginError.new(%(script "#{File.basename(@script)}" not executable\nrun `chmod a+x #{@script.shorten_path}` to correct),
                              plugin: @filename)
      end

      class << self
        def settings
          {
            trigger: @trigger,
            searches: @searches
          }
        end

        def search(search_type, search_terms, link_text)
          type = Shellwords.escape(search_type)
          terms = Shellwords.escape(search_terms)
          text = Shellwords.escape(link_text)

          stdout = `#{[@script, type, terms, text].join(" ")} 2>&1`

          unless $CHILD_STATUS.success?
            raise PluginError.new(%("#{File.basename(@script)}" returned error #{$CHILD_STATUS.exitstatus}\n#{stdout}),
                                  plugin: @filename)
          end

          begin
            res = JSON.parse(stdout)
          rescue JSON::ParserError
            res = YAML.safe_load(stdout)
          end

          unless res.is_a?(Hash)
            raise PluginError.new(%(invalid results from "#{File.basename(@script)}", must be YAML or JSON string),
                                  plugin: @filename)
          end

          %w[url title link_text].each do |key|
            raise PluginError.new(%("#{File.basename(@script)}" output missing key "#{key}"), plugin: @filename) unless res.key?(key)
          end

          [res["url"], res["title"], res["link_text"]]
        end
      end

      SL::Searches.register @name, :search, self
    end

    def find_script(script)
      return File.expand_path(script) if File.exist?(File.expand_path(script))

      base = File.expand_path("~/.config/searchlink/plugins")
      first = File.join(base, script)
      return first if File.exist?(first)

      base = File.expand_path("~/.config/searchlink")
      second = File.join(base, script)
      return second if File.exist?(second)

      raise PluginError.new(%(Script plugin script "#{script}" not found), plugin: @filename)
    end
  end
end
