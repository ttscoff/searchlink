module SL
  class SearchLink
    def make_link(type, text, url, title: false, force_title: false)
      text = title || titleize(url) if @titleize && text == ''

      title = title && (@cfg['include_titles'] || force_title) ? %( "#{title.clean}") : ''
      title.gsub!(/[ \t]+/, ' ')

      case type
      when 'ref_title'
        %(\n[#{text.strip}]: #{url}#{title})
      when 'ref_link'
        %([#{text.strip}][#{url}])
      when 'inline'
        %([#{text.strip}](#{url}#{title}))
      end
    end

    def add_output(str)
      print str if @printout && !@clipboard
      @output += str
    end

    def add_footer(str)
      @footer ||= []
      @footer.push(str.strip)
    end

    def print_footer
      unless @footer.empty?

        footnotes = []
        @footer.delete_if do |note|
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

        output = @footer.sort.join("\n").strip
        output += "\n\n" if !output.empty? && !footnotes.empty?
        output += footnotes.join("\n\n") unless footnotes.empty?
        return output.gsub(/\n{3,}/, "\n\n")
      end

      ''
    end

    def add_report(str)
      return unless @cfg['report']

      unless @line_num.nil?
        position = "#{@line_num}:"
        position += @match_column.nil? ? '0:' : "#{@match_column}:"
        position += @match_length.nil? ? '0' : @match_length.to_s
      end
      @report.push("(#{position}): #{str}")
      warn "(#{position}): #{str}" unless SILENT
    end

    def add_error(type, str)
      return unless @cfg['debug']

      unless @line_num.nil?
        position = "#{@line_num}:"
        position += @match_column.nil? ? '0:' : "#{@match_column}:"
        position += @match_length.nil? ? '0' : @match_length.to_s
      end
      @errors[type] ||= []
      @errors[type].push("(#{position}): #{str}")
    end

    def print_report
      return if (@cfg['inline'] && @originput.split(/\n/).length == 1) || @clipboard

      return if @report.empty?

      out = "\n<!-- Report:\n#{@report.join("\n")}\n-->\n"
      add_output out
    end

    def print_errors(type = 'Errors')
      return if @errors.empty?

      out = ''
      inline = if @originput.split(/\n/).length > 1
                 false
               else
                 @cfg['inline'] || @originput.split(/\n/).length == 1
               end

      @errors.each do |k, v|
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
      if @clipboard
        warn out
      else
        add_output out
      end
    end

    def print_or_copy(text)
      # Process.exit unless text
      if @clipboard
        `echo #{Shellwords.escape(text)}|tr -d "\n"|pbcopy`
        print @originput
      else
        print text
      end
    end
  end
end
