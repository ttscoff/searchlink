$LOAD_PATH.unshift File.join(__dir__, 'lib')
require_relative 'lib/searchlink'
require_relative 'lib/searchlink/semver.rb'
include SL
