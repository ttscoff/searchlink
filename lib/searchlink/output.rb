# frozen_string_literal: true

module SL
  class << self
    attr_writer :titleize, :clipboard, :output, :footer, :line_num,
                :match_column, :match_length, :originput, :errors, :report, :printout

    # Whether or not to add a title to the output
    def titleize
      @titleize ||= false
    end

    # Whether or not to copy results to clipbpard
    def clipboard
      @clipboard ||= false
    end

    # Whether or not to echo results to STDOUT as they're created
    def printout
      @printout ||= false
    end

    # Stores the generated output
    def output
      @output ||= []
    end

    # Stores the generated debug report
    def report
      @report ||= []
    end

    # Stores the footer with reference links and footnotes
    def footer
      @footer ||= []
    end

    # Tracks the line number of each link match for debug output
    def line_num
      @line_num ||= 0
    end

    # Tracks the column of each link match for debug output
    def match_column
      @match_column ||= 0
    end

    # Tracks the length of each link match for debug output
    def match_length
      @match_length ||= 0
    end

    # Stores the original input
    def originput
      @originput ||= ''
    end

    # Stores generated errors
    def errors
      @errors ||= {}
    end

    # Posts macOS notifications
    #
    # @param      str   The title of the notification
    # @param      sub   The text of the notification
    #
    def notify(str, sub)
      return unless SL.config['notifications']

      `osascript -e 'display notification "SearchLink" with title "#{str}" subtitle "#{sub}"'`
    end
  end
end

# The SL module provides methods for creating and manipulating links.
module SL
  class << self
    # Creates a link of the specified type with the given
    # text, url, and title.
    #
    # @param      type         [Symbol] The type of link to
    #                          create.
    # @param      text         [String] The text of the
    #                          link.
    # @param      url          [String] The URL of the link.
    # @param      title        [String] The title of the
    #                          link.
    # @param      force_title  [Boolean] Whether to force
    #                          the title to be included.
    #
    # @return     [String] The link.
    #
    def make_link(type, text, url, title: false, force_title: false)
      title = title.gsub(/\P{Print}|\p{Cf}/, '') if title
      text = title || SL::URL.title(url) if SL.titleize && (!text || text.strip.empty?)
      text = text ? text.strip : title
      title = title && (SL.config['include_titles'] || force_title) ? %( "#{title.clean}") : ''

      title = title.gsub(/[ \t]+/, ' ')

      case type.to_sym
      when :ref_title
        %(\n[#{text}]: #{url}#{title})
      when :ref_link
        %([#{text}][#{url}])
      when :inline
        image = url =~ /\.(gif|jpe?g|png|webp)$/ ? '!' : ''
        %(#{image}[#{text}](#{url}#{title}))
      end
    end

    # Adds the given string to the output.
    #
    # @param      str   [String] The string to add.
    #
    # @return     [nil]
    #
    def add_output(str)
      print str if SL.printout && !SL.clipboard
      SL.output << str
    end

    # Adds the given string to the footer.
    #
    # @param      str   [String] The string to add.
    #
    # @return     [nil]
    #
    def add_footer(str)
      SL.footer ||= []
      SL.footer.push(str.strip)
    end

    # Prints the footer.
    #
    # @return     [String] The footer.
    #
    def print_footer
      unless SL.footer.empty?

        footnotes = []
        SL.footer.delete_if do |note|
          note.strip!
          case note
          when /^\[\^.+?\]/
            footnotes.push(note)
            true
          when /^\s*$/
            true
          else
            false
          end
        end

        output = SL.footer.sort.join("\n").strip
        output += "\n\n" if !output.empty? && !footnotes.empty?
        output += footnotes.join("\n\n") unless footnotes.empty?
        return output.gsub(/\n{3,}/, "\n\n")
      end

      ''
    end

    # Adds the given string to the report.
    #
    # @param      str   [String] The string to add.
    #
    # @return     [nil]
    #
    def add_report(str)
      return unless SL.config['report']

      unless SL.line_num.nil?
        position = "#{SL.line_num}:"
        position += SL.match_column.nil? ? '0:' : "#{SL.match_column}:"
        position += SL.match_length.nil? ? '0' : SL.match_length.to_s
      end
      SL.report.push("(#{position}): #{str}")
      warn "(#{position}): #{str}" unless SILENT
    end

    # Adds the given string to the errors.
    #
    # @param      type  [Symbol] The type of error.
    # @param      str   [String] The string to add.
    #
    # @return     [nil]
    #
    def add_error(type, str)
      return unless SL.config['debug']

      unless SL.line_num.nil?
        position = "#{SL.line_num}:"
        position += SL.match_column.nil? ? '0:' : "#{SL.match_column}:"
        position += SL.match_length.nil? ? '0' : SL.match_length.to_s
      end
      SL.errors[type] ||= []
      SL.errors[type].push("(#{position}): #{str}")
    end

    # Prints the report.
    #
    # @return     [String] The report.
    #
    def print_report
      return if (SL.config['inline'] && SL.originput.split(/\n/).length == 1) || SL.clipboard

      return if SL.report.empty?

      out = "\n<!-- Report:\n#{SL.report.join("\n")}\n-->\n"
      add_output out
    end

    # Prints the errors.
    #
    # @param      type  [String] The type of errors.
    #
    # @return     [String] The errors.
    #
    def print_errors(type = 'Errors')
      return if SL.errors.empty?

      out = ''
      inline = if SL.originput.split(/\n/).length > 1
                 false
               else
                 SL.config['inline'] || SL.originput.split(/\n/).length == 1
               end

      SL.errors.each do |k, v|
        next if v.empty?

        v.each_with_index do |err, i|
          out += "(#{k}) #{err}"
          out += if inline
                   i == v.length - 1 ? ' | ' : ', '
                 else
                   "\n"
                 end
        end
      end

      unless out == ''
        sep = inline ? ' ' : "\n"
        out.sub!(/\| /, '')
        out = "#{sep}<!-- #{type}:#{sep}#{out}-->#{sep}"
      end
      if SL.clipboard
        warn out
      else
        add_output out
      end
    end

    # Prints or copies the given text.
    #
    # @param      text  [String] The text to print or copy.
    #
    # @return     [nil]
    #
    def print_or_copy(text)
      # Process.exit unless text
      if SL.clipboard
        `echo #{Shellwords.escape(text)}|tr -d "\n"|pbcopy`
        print SL.originput
      else
        print text
      end
    end
  end
end
