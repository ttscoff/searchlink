module SL
  class << self
    attr_writer :titleize, :clipboard, :output, :footer, :line_num,
                :match_column, :match_length, :originput, :errors, :report, :printout

    def titleize
      @titleize ||= false
    end

    def clipboard
      @clipboard ||= false
    end

    def printout
      @printout ||= false
    end

    def output
      @output ||= []
    end

    def report
      @report ||= []
    end

    def footer
      @footer ||= []
    end

    def line_num
      @line_num ||= 0
    end

    def match_column
      @match_column ||= 0
    end

    def match_length
      @match_length ||= 0
    end

    def originput
      @originput ||= ''
    end

    def errors
      @errors ||= {}
    end

    def notify(str, sub)
      return unless SL.config['notifications']

      `osascript -e 'display notification "SearchLink" with title "#{str}" subtitle "#{sub}"'`
    end
  end
end

module SL
  class << self
    def make_link(type, text, url, title: false, force_title: false)
      title = title.gsub(/\P{Print}|\p{Cf}/, '') if title
      text = title || SL::URL.get_title(url) if SL.titleize && (!text || text.strip.empty?)
      text = text ? text.strip : title
      title = title && (SL.config['include_titles'] || force_title) ? %( "#{title.clean}") : ''

      title.gsub!(/[ \t]+/, ' ')

      case type.to_sym
      when :ref_title
        %(\n[#{text}]: #{url}#{title})
      when :ref_link
        %([#{text}][#{url}])
      when :inline
        %([#{text}](#{url}#{title}))
      end
    end

    def add_output(str)
      print str if SL.printout && !SL.clipboard
      SL.output << str
    end

    def add_footer(str)
      SL.footer ||= []
      SL.footer.push(str.strip)
    end

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

    def print_report
      return if (SL.config['inline'] && SL.originput.split(/\n/).length == 1) || SL.clipboard

      return if SL.report.empty?

      out = "\n<!-- Report:\n#{SL.report.join("\n")}\n-->\n"
      add_output out
    end

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
