#!/usr/bin/env ruby
# frozen_string_literal: true

class ::String
  def import_markers(base)
    gsub(/^# *import\nrequire(?:_relative)? '(.*?)'\n/) do
      file = Regexp.last_match(1)
      file = File.join(base, "#{file}.rb")

      content = IO.read(file)
      content.import_markers(File.dirname(file))
    end
  end

  def import_markers!(base)
    replace import_markers(base)
  end
end

source_file = File.expand_path('bin/searchlink')
source = IO.read(source_file)

source.import_markers!(File.join(File.dirname(source_file), '..'))

source.sub!(/#{Regexp.escape(%($LOAD_PATH.unshift File.join(__dir__, '..')))}/, '')

File.open('searchlink.rb', 'w') { |f| f.puts source }

puts "Compiled searchlink.rb"
