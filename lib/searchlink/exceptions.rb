# frozen_string_literal: true

module SL
  # Custom Semantic Versioning error
  class VersionError < StandardError
    def initialize(msg)
      msg = msg ? ": #{msg}" : ""
      warn "Versioning error#{msg}"

      super("Versioning error#{msg}")

      Process.exit 1
    end
  end

  # Custom plugin error. Does not abort the process; callers that load
  # optional plugins should rescue this and continue.
  class PluginError < StandardError
    def initialize(msg = nil, plugin: nil)
      plugin = %("#{plugin}") if plugin
      plugin ||= "plugin"
      msg = ": #{msg}" if msg
      message = "Error in #{plugin}#{msg}"
      warn message

      super(message)
    end
  end
end
