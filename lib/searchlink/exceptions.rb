# frozen_string_literal: true

module SL
  # Custom Semantic Versioning error
  class VersionError < StandardError
    def initialize(msg)
      msg = msg ? ": #{msg}" : ""
      puts "Versioning error#{msg}"

      super()

      Process.exit 1
    end
  end

  # Custom plugin error
  class PluginError < StandardError
    def initialize(msg = nil, plugin: nil)
      plugin = %("#{plugin}") if plugin
      plugin ||= "plugin"
      msg = ": #{msg}" if msg
      puts "Error in #{plugin}#{msg}"

      super()

      Process.exit 1
    end
  end
end
