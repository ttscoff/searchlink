#!/usr/bin/env ruby
# frozen_string_literal: true

class ::String
  def import_markers(base)
    gsub(/^<<\[(.*?)\]/) do
      file = Regexp.last_match(1)
      file = File.join(base, file)

      content = IO.read(file)
      content.import_markers(File.dirname(file))
    end
  end

  def import_markers!(base)
    replace import_markers(base)
  end
end

source_file = File.expand_path('searchlink.src.rb')
source = IO.read(source_file)

source.import_markers!(File.dirname(source_file))

File.open('searchlink.rb', 'w') { |f| f.puts source }
