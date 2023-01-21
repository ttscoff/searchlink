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

# sources = [source]
# Dir.glob('lib/searchlink/searches/*.rb').each do |f|
#   content = IO.read(f)
#   content.import_markers(File.dirname(f))
#   sources.push(content)
# end
# source = sources.join("\n")

source.sub!(/#{Regexp.escape(%($LOAD_PATH.unshift File.join(__dir__, '..')))}/, '')
# source.sub!(/^# *ignore *\n.*?$/, '')

File.open('searchlink.rb', 'w') { |f| f.puts source }

puts "Compiled searchlink.rb"
