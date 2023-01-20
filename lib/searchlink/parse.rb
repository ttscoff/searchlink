module SL
  class SearchLink
    def parse_arguments(string, opt={})
      input = string.dup
      return "" if input.nil?

      skip_flags = opt[:only_meta] || false
      no_restore = opt[:no_restore] || false
      restore_prev_config unless no_restore

      unless skip_flags
        input.parse_flags!
      end

      options = %w[debug country_code inline prefix_random include_titles validate_links]
      options.each do |o|
        if input =~ /^ *#{o}:\s+(\S+)$/
          val = Regexp.last_match(1).strip
          val = true if val =~ /true/i
          val = false if val =~ /false/i
          @cfg[o] = val
          $stderr.print "\r\033[0KGlobal config: #{o} = #{@cfg[o]}\n" unless SILENT
        end

        next if skip_flags

        while input =~ /^#{o}:\s+(.*?)$/ || input =~ /--(no-)?#{o}/
          next unless input =~ /--(no-)?#{o}/ && !skip_flags

          unless @prev_config.key? o
            @prev_config[o] = @cfg[o]
            bool = Regexp.last_match(1).nil? || Regexp.last_match(1) == '' ? true : false
            @cfg[o] = bool
            $stderr.print "\r\033[0KLine config: #{o} = #{@cfg[o]}\n" unless SILENT
          end
          input.sub!(/\s?--(no-)?#{o}/, '')
        end
      end
      @clipboard ? string : input
    end

    def parse_commands(input)
      # Handle commands like help or docs
      if input.strip =~ /^(h(elp)?|wiki|docs?|v(er(s(ion)?)?)?|up(date|grade))$/
        case input.strip
        when /^help$/i
          if SILENT
            help_dialog # %x{open http://brettterpstra.com/projects/searchlink/}
          else
            $stdout.puts "#{SL::version_check}"
            $stdout.puts 'See https://github.com/ttscoff/searchlink/wiki for help'
          end
          print input
        when /^(wiki|docs)$/i
          warn "Opening wiki in browser"
          `open https://github.com/ttscoff/searchlink/wiki`
        when /^v(er(s(ion)?)?)?$/
          print "[#{SL::version_check}]"
        when /^up(date|grade)$/
          update_searchlink
        end
        Process.exit 0
      end
    end

    def parse(input)
      @output = ''
      return false if input.empty?

      parse_arguments(input, { only_meta: true })
      @originput = input.dup

      parse_commands(input)

      @cfg['inline'] = true if input.scan(/\]\(/).length == 1 && input.split(/\n/).length == 1
      @errors = {}
      @report = []

      # Check for new version
      latest_version = SL::new_version?
      add_output("<!-- v#{latest_version} available, run SearchLink on the word 'update' to install. -->") if latest_version

      links = {}
      @footer = []
      counter_links = 0
      counter_errors = 0

      input.sub!(/\n?<!-- Report:.*?-->\n?/m, '')
      input.sub!(/\n?<!-- Errors:.*?-->\n?/m, '')

      input.scan(/\[(.*?)\]:\s+(.*?)\n/).each { |match| links[match[1].strip] = match[0] }

      prefix = if @cfg['prefix_random']
                 if input =~ /\[(\d{4}-)\d+\]: \S+/
                   Regexp.last_match(1)
                 else
                   format('%04d-', rand(9999))
                 end
               else
                 ''
               end

      highest_marker = 0
      input.scan(/^\s{,3}\[(?:#{prefix})?(\d+)\]: /).each do
        m = Regexp.last_match
        highest_marker = m[1].to_i if m[1].to_i > highest_marker
      end

      footnote_counter = 0
      input.scan(/^\s{,3}\[\^(?:#{prefix})?fn(\d+)\]: /).each do
        m = Regexp.last_match
        footnote_counter = m[1].to_i if m[1].to_i > footnote_counter
      end

      if input =~ /\[(.*?)\]\((.*?)\)/
        lines = input.split(/\n/)
        out = []

        total_links = input.scan(/\[(.*?)\]\((.*?)\)/).length
        in_code_block = false
        line_difference = 0
        lines.each_with_index do |line, num|
          @line_num = num - line_difference
          cursor_difference = 0
          # ignore links in code blocks
          if line =~ /^( {4,}|\t+)[^*+\-]/
            out.push(line)
            next
          end
          if line =~ /^[~`]{3,}/
            if in_code_block
              in_code_block = false
              out.push(line)
              next
            else
              in_code_block = true
            end
          end
          if in_code_block
            out.push(line)
            next
          end

          delete_line = false

          search_count = 0

          line.gsub!(/\[(.*?)\]\((.*?)\)/) do |match|
            this_match = Regexp.last_match
            @match_column = this_match.begin(0) - cursor_difference
            match_string = this_match.to_s
            @match_length = match_string.length
            match_before = this_match.pre_match

            invalid_search = false
            ref_title = false

            if match_before.scan(/(^|[^\\])`/).length.odd?
              add_report("Match '#{match_string}' within an inline code block")
              invalid_search = true
            end

            counter_links += 1
            unless SILENT
              $stderr.print("\033[0K\rProcessed: #{counter_links} of #{total_links}, #{counter_errors} errors. ")
            end

            link_text = this_match[1] || ''
            link_info = parse_arguments(this_match[2].strip).strip || ''

            if link_text.strip == '' && link_info =~ /".*?"/
              link_info.gsub!(/"(.*?)"/) do
                m = Regexp.last_match(1)
                link_text = m if link_text == ''
                m
              end
            end

            if link_info.strip =~ /:$/ && line.strip == match
              ref_title = true
              link_info.sub!(/\s*:\s*$/, '')
            end

            unless !link_text.empty? || !link_info.sub(/^[!\^]\S+/, '').strip.empty?
              add_error('No input', match)
              counter_errors += 1
              invalid_search = true
            end

            if link_info =~ /^!(\S+)/
              search_type = Regexp.last_match(1)
              unless valid_search?(search_type) || search_type =~ /^(\S+\.)+\S+$/
                add_error("Invalid search#{did_you_mean(search_type)}", match)
                invalid_search = true
              end
            end

            if invalid_search
              match
            elsif link_info =~ /^\^(.+)/
              m = Regexp.last_match
              if m[1].nil? || m[1] == ''
                match
              else
                note = m[1].strip
                footnote_counter += 1
                ref = if !link_text.empty? && link_text.scan(/\s/).empty?
                        link_text
                      else
                        format('%<p>sfn%<c>04d', p: prefix, c: footnote_counter)
                      end
                add_footer "[^#{ref}]: #{note}"
                res = "[^#{ref}]"
                cursor_difference += (@match_length - res.length)
                @match_length = res.length
                add_report("#{match_string} => Footnote #{ref}")
                res
              end
            elsif (link_text == '' && link_info == '') || url?(link_info)
              add_error("Invalid search", match) unless url?(link_info)
              match
            else
              link_info = link_text if !link_text.empty? && link_info == ''

              search_type = ''
              search_terms = ''
              link_only = false
              @clipboard = false
              @titleize = @cfg['empty_uses_page_title']

              if link_info =~ /^(?:[!\^](\S+))\s*(.*)$/
                m = Regexp.last_match

                search_type = m[1].nil? ? 'g' : m[1]

                search_terms = m[2].gsub(/(^["']|["']$)/, '')
                search_terms.strip!

                # if the link text is just '%' replace with title regardless of config settings
                if link_text == '%' && search_terms && !search_terms.empty?
                  @titleize = true
                  link_text = ''
                end

                search_terms = link_text if search_terms == ''

                # if the input starts with a +, append it to the link text as the search terms
                search_terms = "#{link_text} #{search_terms.strip.sub(/^\+\s*/, '')}" if search_terms.strip =~ /^\+[^+]/

                # if the end of input contain "^", copy to clipboard instead of STDOUT
                @clipboard = true if search_terms =~ /(!!)?\^(!!)?$/

                # if the end of input contains "!!", only print the url
                link_only = true if search_terms =~ /!!\^?$/

                search_terms.sub!(/(!!)?\^?(!!)?$/,"")

              elsif link_info =~ /^!/
                search_word = link_info.match(/^!(\S+)/)

                if search_word && valid_search?(search_word[1])
                  search_type = search_word[1] unless search_word.nil?
                  search_terms = link_text
                elsif search_word && search_word[1] =~ /^(\S+\.)+\S+$/
                  search_type = 'g'
                  search_terms = "site:#{search_word[1]} #{link_text}"
                else
                  add_error("Invalid search#{did_you_mean(search_word[1])}", match)
                  search_type = false
                  search_terms = false
                end
              elsif link_text && !link_text.empty? && (link_info.nil? || link_info.empty?)
                search_type = 'g'
                search_terms = link_text
              elsif link_info && !link_info.empty?
                search_type = 'g'
                search_terms = link_info
              else
                add_error('Invalid search', match)
                search_type = false
                search_terms = false
              end

              if search_type && !search_terms.empty?
                @cfg['custom_site_searches'].each do |k, v|
                  next unless search_type == k

                  link_text = search_terms if !@titleize && link_text == ''
                  v = parse_arguments(v, { no_restore: true })
                  if v =~ %r{^(/|http)}i
                    search_type = 'r'
                    tokens = v.scan(/\$term\d+[ds]?/).sort.uniq

                    if !tokens.empty?
                      highest_token = 0
                      tokens.each do |token|
                        if token =~ /(\d+)[ds]?$/ && Regexp.last_match(1).to_i > highest_token
                          highest_token = Regexp.last_match(1).to_i
                        end
                      end
                      terms_p = search_terms.split(/ +/)
                      if terms_p.length > highest_token
                        remainder = terms_p[highest_token - 1..-1].join(' ')
                        terms_p = terms_p[0..highest_token - 2]
                        terms_p.push(remainder)
                      end
                      tokens.each do |t|
                        next unless t =~ /(\d+)[ds]?$/

                        int = Regexp.last_match(1).to_i - 1
                        replacement = terms_p[int]
                        case t
                        when /d$/
                          replacement.downcase!
                          re_down = ''
                        when /s$/
                          replacement.slugify!
                          re_down = ''
                        else
                          re_down = '(?!d|s)'
                        end
                        v.gsub!(/#{Regexp.escape(t) + re_down}/, ERB::Util.url_encode(replacement))
                      end
                      search_terms = v
                    else
                      search_terms = v.gsub(/\$term[ds]?/i) do |mtch|
                        search_terms.downcase! if mtch =~ /d$/i
                        search_terms.slugify! if mtch =~ /s$/i
                        ERB::Util.url_encode(search_terms)
                      end
                    end
                  else
                    search_type = 'g'
                    search_terms = "site:#{v} #{search_terms}"
                  end

                  break
                end
              end

              if search_type && search_terms
                # warn "Searching #{search_type} for #{search_terms}"
                search_count += 1

                url, title, link_text = do_search(search_type, search_terms, link_text, search_count)

                if url
                  title = titleize(url) if @titleize && title == ''

                  link_text = title if link_text == '' && title
                  force_title = search_type =~ /def/ ? true : false

                  if link_only || search_type =~ /sp(ell)?/ || url == 'embed'
                    url = title if url == 'embed'
                    cursor_difference += @match_length - url.length
                    @match_length = url.length
                    add_report("#{match_string} => #{url}")
                    url
                  elsif ref_title
                    unless links.key? url
                      links[url] = link_text
                      add_footer make_link('ref_title', link_text, url, title: title, force_title: force_title)
                    end
                    delete_line = true
                  elsif @cfg['inline']
                    res = make_link('inline', link_text, url, title: title, force_title: force_title)
                    cursor_difference += @match_length - res.length
                    @match_length = res.length
                    add_report("#{match_string} => #{url}")
                    res
                  else
                    unless links.key? url
                      highest_marker += 1
                      links[url] = format('%<pre>s%<m>04d', pre: prefix, m: highest_marker)
                      add_footer make_link('ref_title', links[url], url, title: title, force_title: force_title)
                    end

                    type = @cfg['inline'] ? 'inline' : 'ref_link'
                    res = make_link(type, link_text, links[url], title: false, force_title: force_title)
                    cursor_difference += @match_length - res.length
                    @match_length = res.length
                    add_report("#{match_string} => #{url}")
                    res
                  end
                else
                  add_error('No results', "#{search_terms} (#{match_string})")
                  counter_errors += 1
                  match
                end
              else
                add_error('Invalid search', match)
                counter_errors += 1
                match
              end
            end
          end
          line_difference += 1 if delete_line
          out.push(line) unless delete_line
          delete_line = false
        end
        warn "\n" unless SILENT

        input = out.delete_if { |l| l.strip =~ /^<!--DELETE-->$/ }.join("\n")

        if @cfg['inline']
          add_output "#{input}\n"
          add_output "\n#{print_footer}" unless @footer.empty?
        elsif @footer.empty?
          add_output input
        else
          last_line = input.strip.split(/\n/)[-1]
          case last_line
          when /^\[.*?\]: http/
            add_output "#{input.rstrip}\n"
          when /^\[\^.*?\]: /
            add_output input.rstrip
          else
            add_output "#{input}\n\n"
          end
          add_output "#{print_footer}\n\n"
        end
        @line_num = nil
        add_report("Processed: #{total_links} links, #{counter_errors} errors.")
        print_report
        print_errors
      else
        link_only = false
        @clipboard = false

        res = parse_arguments(input.strip!).strip
        input = res.nil? ? input.strip : res

        # if the end of input contain "^", copy to clipboard instead of STDOUT
        @clipboard = true if input =~ /\^[!~:\s]*$/

        # if the end of input contains "!!", only print the url
        link_only = true if input =~ /!![\^~:\s]*$/

        reference_link = input =~ /:([!\^~\s]*)$/

        # if end of input contains ~, pull url from clipboard
        if input =~ /~[:\^!\s]*$/
          input.sub!(/[:!\^\s~]*$/, '')
          clipboard = `__CF_USER_TEXT_ENCODING=$UID:0x8000100:0x8000100 pbpaste`.strip
          if url?(clipboard)
            type = reference_link ? 'ref_title' : 'inline'
            print make_link(type, input.strip, clipboard)
          else
            print @originput
          end
          Process.exit
        end

        input.sub!(/[:!\^\s~]*$/, '')

        ## Maybe if input is just a URL, convert it to a link
        ## using hostname as text without doing search
        if only_url?(input.strip)
          type = reference_link ? 'ref_title' : 'inline'
          url, title = url_to_link(input.strip, type)
          print make_link(type, title, url, title: false, force_title: false)
          Process.exit
        end

        # check for additional search terms in parenthesis
        additional_terms = ''
        if input =~ /\((.*?)\)/
          additional_terms = " #{Regexp.last_match(1).strip}"
          input.sub!(/\(.*?\)/, '')
        end

        # Maybe detect "search + addition terms" and remove additional terms from link text?
        # if input =~ /\+(.+?)$/
        #   additional_terms = "#{additional_terms} #{Regexp.last_match(1).strip}"
        #   input.sub!(/\+.*?$/, '').strip!
        # end

        link_text = false

        if input =~ /"(.*?)"/
          link_text = Regexp.last_match(1)
          input.gsub!(/"(.*?)"/, '\1')
        end

        # remove quotes from terms, just in case
        # input.sub!(/^(!\S+)?\s*(["'])(.*?)\2([\!\^]+)?$/, "\\1 \\3\\4")

        case input
        when /^!(\S+)\s+(.*)$/
          type = Regexp.last_match(1)
          link_info = Regexp.last_match(2).strip
          link_text ||= link_info
          terms = link_info + additional_terms
          terms.strip!

          if valid_search?(type) || type =~ /^(\S+\.)+\S+$/
            if type && terms && !terms.empty?
              @cfg['custom_site_searches'].each do |k, v|
                next unless type == k

                link_text = terms if link_text == ''
                v = parse_arguments(v, { no_restore: true })
                if v =~ %r{^(/|http)}i
                  type = 'r'
                  tokens = v.scan(/\$term\d+[ds]?/).sort.uniq

                  if !tokens.empty?
                    highest_token = 0
                    tokens.each do |token|
                      t = Regexp.last_match(1)
                      highest_token = t.to_i if token =~ /(\d+)d?$/ && t.to_i > highest_token
                    end
                    terms_p = terms.split(/ +/)
                    if terms_p.length > highest_token
                      remainder = terms_p[highest_token - 1..-1].join(' ')
                      terms_p = terms_p[0..highest_token - 2]
                      terms_p.push(remainder)
                    end
                    tokens.each do |t|
                      next unless t =~ /(\d+)d?$/

                      int = Regexp.last_match(1).to_i - 1
                      replacement = terms_p[int]
                      case t
                      when /d$/
                        replacement.downcase!
                        re_down = ''
                      when /s$/
                        replacement.slugify!
                        re_down = ''
                      else
                        re_down = '(?!d|s)'
                      end
                      v.gsub!(/#{Regexp.escape(t) + re_down}/, ERB::Util.url_encode(replacement))
                    end
                    terms = v
                  else
                    terms = v.gsub(/\$term[ds]?/i) do |mtch|
                      terms.downcase! if mtch =~ /d$/i
                      terms.slugify! if mtch =~ /s$/i
                      ERB::Util.url_encode(terms)
                    end
                  end
                else
                  type = 'g'
                  terms = "site:#{v} #{terms}"
                end

                break
              end
            end

            if type =~ /^(\S+\.)+\S+$/
              terms = "site:#{type} #{terms}"
              type = 'g'
            end
            search_count ||= 0
            search_count += 1
            url, title, link_text = do_search(type, terms, link_text, search_count)
          else
            add_error("Invalid search#{did_you_mean(type)}", input)
            counter_errors += 1
          end
        when /^([tfilm])?@(\S+)\s*$/
          type = Regexp.last_match(1)
          unless type
            if Regexp.last_match(2) =~ /[a-z0-9_]@[a-z0-9_.]+/i
              type = 'm'
            else
              type = 't'
            end
          end
          link_text = input.sub(/^[tfilm]/, '')
          url, title = social_handle(type, link_text)
          link_text = title
        else
          link_text ||= input
          url, title = ddg(input)
        end

        if url
          if type =~ /sp(ell)?/
            add_output(url)
          elsif link_only
            add_output(url)
          elsif url == 'embed'
            add_output(title)
          else
            type = reference_link ? 'ref_title' : 'inline'
            add_output make_link(type, link_text, url, title: title, force_title: false)
            print_errors
          end
        else
          add_error('No results', title)
          add_output @originput.chomp
          print_errors
        end

        if @clipboard
          if @output == @originput
            warn "No results found"
          else
            `echo #{Shellwords.escape(@output)}|tr -d "\n"|pbcopy`
            warn "Results in clipboard"
          end
        end
      end
    end
  end
end
