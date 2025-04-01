# frozen_string_literal: true

# = plist
#
# Copyright 2006-2010 Ben Bleything and Patrick May
# Distributed under the MIT License
module Plist; end

# === Load a plist file
# This is the main point of the library:
#
#   r = Plist::parse_xml( filename_or_xml )
module Plist
  def self.parse_xml(filename_or_xml)
    listener = Listener.new
    parser = StreamParser.new(filename_or_xml, listener)
    parser.parse
    listener.result
  end

  class Listener
    attr_accessor :result, :open

    def initialize
      @result = nil
      @open = []
    end

    def tag_start(name, _attributes)
      @open.push PTag.mappings[name].new
    end

    def text(contents)
      @open.last.text = contents if @open.last
    end

    def tag_end(_name)
      last = @open.pop
      if @open.empty?
        @result = last.to_ruby
      else
        @open.last.children.push last
      end
    end
  end

  class StreamParser
    def initialize(plist_data_or_file, listener)
      @xml = if plist_data_or_file.respond_to? :read
               plist_data_or_file.read
             elsif File.exist? plist_data_or_file
               File.read(plist_data_or_file)
             else
               plist_data_or_file
             end

      @listener = listener
    end

    TEXT = /([^<]+)/.freeze
    XMLDECL_PATTERN = /<\?xml\s+(.*?)\?>*/um.freeze
    DOCTYPE_PATTERN = /\s*<!DOCTYPE\s+(.*?)(\[|>)/um.freeze
    COMMENT_START = /\A<!--/u.freeze
    COMMENT_END = /.*?-->/um.freeze

    def parse
      plist_tags = PTag.mappings.keys.join("|")
      start_tag = /<(#{plist_tags})([^>]*)>/i
      end_tag = %r{</(#{plist_tags})[^>]*>}i

      require "strscan"

      @scanner = StringScanner.new(@xml)
      until @scanner.eos?
        next unless @scanner.scan(COMMENT_START)

        @scanner.scan(COMMENT_END)
        if @scanner.scan(start_tag)
          @listener.tag_start(@scanner[1], nil)
          @listener.tag_end(@scanner[1]) if @scanner[2] =~ %r{/$}
        elsif @scanner.scan(TEXT)
          @listener.text(@scanner[1])
        elsif @scanner.scan(end_tag)
          @listener.tag_end(@scanner[1])
        else
          raise "Unimplemented element"
        end
      end
    end

    class PTag
      @@mappings = {}
      def self.mappings
        @@mappings
      end

      def self.inherited(sub_class)
        key = sub_class.to_s.downcase
        key.gsub!(/^plist::/, "")
        key.gsub!(/^p/, "") unless key == "plist"

        @@mappings[key] = sub_class
        super
      end

      attr_accessor :text, :children

      def initialize
        @children = []
      end

      def to_ruby
        raise "Unimplemented: #{self.class}#to_ruby on #{inspect}"
      end
    end

    class PList < PTag
      def to_ruby
        children.first&.to_ruby
      end
    end

    class PDict < PTag
      def to_ruby
        dict = {}
        key = nil

        children.each do |c|
          if key.nil?
            key = c.to_ruby
          else
            dict[key] = c.to_ruby
            key = nil
          end
        end

        dict
      end
    end

    class PKey < PTag
      def to_ruby
        CGI.unescapeHTML(text || "")
      end
    end

    class PString < PTag
      def to_ruby
        CGI.unescapeHTML(text || "")
      end
    end

    class PArray < PTag
      def to_ruby
        children.collect(&:to_ruby)
      end
    end

    class PInteger < PTag
      def to_ruby
        text.to_i
      end
    end

    class PTrue < PTag
      def to_ruby
        true
      end
    end

    class PFalse < PTag
      def to_ruby
        false
      end
    end

    class PReal < PTag
      def to_ruby
        text.to_f
      end
    end

    require "date"

    class PDate < PTag
      def to_ruby
        DateTime.parse(text)
      end
    end

    require "base64"

    class PData < PTag
      def to_ruby
        data = Base64.decode64(text.gsub(/\s+/, ""))

        begin
          Marshal.load(data)
        rescue Exception
          io = StringIO.new
          io.write data
          io.rewind
          io
        end
      end
    end
  end
end

# module Plist
#   VERSION = '3.1.0'
# end
