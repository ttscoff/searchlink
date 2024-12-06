# frozen_string_literal: true

# SearchLink by Brett Terpstra 2015 <http://brettterpstra.com/projects/searchlink/>
# MIT License, please maintain attribution
require "net/https"
require "uri"
require "shellwords"
require "yaml"
require "cgi"
require "fileutils"
require "tempfile"
require "zlib"
require "time"
require "json"
require "erb"
require "English"

# import
require_relative "tokens" if File.exist?("tokens.rb")

# import
require_relative "searchlink/exceptions"

# import
require_relative "searchlink/number"

# import
require_relative "searchlink/util"

# import
require_relative "searchlink/curl"

# import
require_relative "searchlink/semver"

# import
require_relative "searchlink/version"

# import
require_relative "searchlink/array"

# import
require_relative "searchlink/string"

# import
require_relative "searchlink/plist"

# import
require_relative "searchlink/config"

# import
require_relative "searchlink/searches"

# import
require_relative "searchlink/url"

# import
require_relative "searchlink/search"

# import
require_relative "searchlink/help"

# import
require_relative "searchlink/parse"

# import
require_relative "searchlink/output"

# import
require_relative "searchlink/which"

# import
require_relative "searchlink/script_plugin"

module Secrets; end
