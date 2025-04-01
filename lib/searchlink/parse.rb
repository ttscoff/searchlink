# frozen_string_literal: true

module SL
  class SearchLink
    # Confirm a URL with a popup if requested
    def confirmed?(url)
      return true if !SL.config["confirm"] || NO_CONFIRM

      SL::Shortener.confirm?(url)
    end

    # Parse the input string and perform searches
    def parse(input)
      SL.output = []
      return false if input.empty?

      parse_arguments(input, { only_meta: true })
      SL.originput = input.dup

      parse_commands(input)

      SL.config["inline"] = true if input.scan(/\]\(/).length == 1 && input.split(/\n/).length == 1
      SL.errors = {}
      SL.report = []
      SL.shortener = :none

      # Check for new version
      latest_version = SL.new_version?
      if latest_version
        SL.add_output("<!-- v#{latest_version} available, run SearchLink on the word 'update' to install. -->")
      end

      @links = {}
      SL.footer = []
      counter_links = 0
      counter_errors = 0

      input.sub!(/\n?<!-- Report:.*?-->\n?/m, "")
      input.sub!(/\n?<!-- Errors:.*?-->\n?/m, "")

      input.scan(/\[(.*?)\]:\s+(.*?)\n/).each { |match| @links[match[1].strip] = match[0] }

      @prefix = if SL.config["prefix_random"]
          if input =~ /\[(\d{4}-)\d+\]: \S+/
            Regexp.last_match(1)
          else
            format("%04d-", rand(9999))
          end
        else
          ""
        end

      @highest_marker = 0
      input.scan(/^\s{,3}\[(?:#{@prefix})?(\d+)\]: /).each do
        m = Regexp.last_match
        @highest_marker = m[1].to_i if m[1].to_i > @highest_marker
      end

      @footnote_counter = 0
      input.scan(/^\s{,3}\[\^(?:#{@prefix})?fn(\d+)\]: /).each do
        m = Regexp.last_match
        @footnote_counter = m[1].to_i if m[1].to_i > @footnote_counter
      end

      if SL.config["complete_bare"]
        rx = %r{(?ix-m)(?<!\(|:\s|<)(?:
                (?:https?://)(?:[\da-z.-]+)\.(?:[a-z.]{2,6})
                (?:[/\w\d.\-()_/+=?&%]*?(?=[\s\n]|$))
              )}
        input.gsub!(rx) do
          url_match = Regexp.last_match
          url_match.pre_match =~ /!\S+ +$/ ? url_match[0] : "[%](#{url_match[0]})"
        end
      end

      if input =~ /\[\n(.*?\n)+\]\((.*?)?\)/
        input.gsub!(/\[\n(((\s*(?:[-+*]|\d+\.)?\s+)*(!\S+ +)?(.*?))\n)+\]\((!\S+.*?)?\)/) do
          m = Regexp.last_match
          lines = m[0].split(/\n/)
          lines = lines[1..-2]
          lines.map do |l|
            el_rx = /(\s*(?:[-+*]|\d+\.)?\s+)?(!\S+ )?(\w.*?)$/
            if l =~ el_rx
              els = l.match(el_rx)
              search = if els[2]
                  els[2].strip
                else
                  m[6] || "!g"
                end
              "#{els[1]}[#{els[3].strip}](#{search})"
            else
              l
            end
          end.join("\n")
        end
      end

      # Handle links in the form of [text](url) or [text](url "title")
      if input =~ /\[(.*?)\]\((.*?)\)/
        lines = input.split(/\n/)
        out = []

        total_links = input.scan(/\[(.*?)\]\((.*?)\)/).length
        in_code_block = false
        line_difference = 0
        lines.each_with_index do |line, num|
          SL.line_num = num - line_difference
          @cursor_difference = 0
          # ignore links in code blocks
          if line =~ /^(( {4,}|\t+)[^*+-])/
            out.push(line)
            next
          end
          if line =~ /^\s*[~`]{3,}/
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

          @delete_line = false

          @search_count = 0

          line.gsub!(/\[(.*?)\]\((.*?)\)/) do |match|
            this_match = Regexp.last_match

            SL.match_column = this_match.begin(0) - @cursor_difference
            @match_string = this_match.to_s
            SL.match_length = @match_string.length
            match_before = this_match.pre_match

            invalid_search = false
            @ref_title = false

            if match_before.scan(/(^|[^\\])`/).length.odd?
              SL.add_report("Match '#{@match_string}' within an inline code block")
              invalid_search = true
            end

            counter_links += 1
            unless SILENT
              $stderr.print("\033[0K\rProcessed: #{counter_links} of #{total_links}, #{counter_errors} errors. ")
            end

            @link_text = this_match[1] || ""
            link_info = parse_arguments(this_match[2].strip).strip || ""
            query, link_info = link_info.extract_query({})

            if @link_text.strip == "" && link_info =~ /".*?"/
              link_info.gsub!(/"(.*?)"/) do
                m = Regexp.last_match
                @link_text = m[1] if @link_text == ""
                m[0]
              end
            end

            link_info.gsub!(/<(.*?)>/) do
              %(%22#{Regexp.last_match(1)}%22)
            end

            if link_info.strip =~ /:$/ && line.strip == match
              @ref_title = true
              link_info.sub!(/\s*:\s*$/, "")
            end

            if @link_text.empty? && link_info.sub(/^[!\^]\S+/, "").strip.empty?
              SL.add_error("No input", match)
              counter_errors += 1
              invalid_search = true
            end

            if link_info =~ /^!(\S+)/
              search_type = Regexp.last_match(1).extract_shortener
              unless SL::Searches.valid_search?(search_type) || search_type =~ /^(\S+\.)+\S+$/
                SL.add_error("Invalid search#{SL::Searches.did_you_mean(search_type)}", match)
                invalid_search = true
              end
            end

            if invalid_search
              match
            elsif link_info =~ /^\^(.+)/
              m = Regexp.last_match
              create_footnote(m)
              # Handle [](URL) and [%](URL), filling in title
            elsif (@link_text == "" || @link_text == "%") && SL::URL.url?(link_info)
              add_title(link_info)
            elsif (@link_text == "" && link_info == "") || SL::URL.url?(link_info)
              SL.add_error("Invalid search", match) unless SL::URL.url?(link_info)
              match
            else
              link_info = @link_text if !@link_text.empty? && link_info == ""

              search_type = ""
              search_terms = ""
              link_only = false
              SL.clipboard = false
              SL.titleize = SL.config["empty_uses_page_title"]

              if link_info =~ /^(?:[!\^](\S+))\s*(.*)$/
                m = Regexp.last_match

                search_type = if m[1].nil?
                    SL::GoogleSearch.api_key? ? "gg" : "g"
                  else
                    m[1]
                  end

                search_type.extract_shortener!

                search_terms = m[2].gsub(/(^["']|["']$)/, "")
                search_terms.strip!

                # if the link text is just '%' replace with title regardless of config settings
                if @link_text == "%" && search_terms && !search_terms.empty?
                  SL.titleize = true
                  @link_text = ""
                end

                search_terms = @link_text if search_terms == ""

                # if the input starts with a +, append it to the link text as the search terms
                if search_terms.strip =~ /^\+[^+]/
                  search_terms = "#{@link_text} #{search_terms.strip.sub(/^\+\s*/, "")}"
                end

                # if the end of input contain "^", copy to clipboard instead of STDOUT
                SL.clipboard = true if search_terms =~ /(!!)?\^(!!)?$/

                # if the end of input contains "!!", only print the url
                link_only = true if search_terms =~ /!!\^?$/

                search_terms = search_terms.sub(/(!!)?\^?(!!)?$/, "")

                if search_type =~ /^(\S+\.)+\S+$/
                  search_type = "g"
                  search_terms = "site:#{m[1]} #{search_terms}"
                end
              elsif link_info =~ /^!/
                search_word = link_info.match(/^!(\S+)/)
                st = search_word[1].extract_shortener
                if search_word && SL::Searches.valid_search?(st)
                  search_type = st unless search_word.nil?
                  search_terms = @link_text
                elsif search_word && st =~ /^(\S+\.)+\S+$/
                  search_type = SL::GoogleSearch.api_key? ? "gg" : "g"
                  search_terms = "site:#{search_word[1]} #{@link_text}"
                else
                  SL.add_error("Invalid search#{SL::Searches.did_you_mean(st)}", match)
                  search_type = false
                  search_terms = false
                end
              elsif @link_text && !@link_text.empty? && (!link_info || link_info.empty?)
                search_type = SL::GoogleSearch.api_key? ? "gg" : "g"
                search_terms = @link_text
              elsif link_info && !link_info.empty?
                search_type = SL::GoogleSearch.api_key? ? "gg" : "g"
                search_terms = link_info
              else
                SL.add_error("Invalid search", match)
                search_type = false
                search_terms = false
              end

              if search_type && !search_terms.empty?
                search_type, search_terms = custom_search(search_type, search_terms)
              end

              SL.add_query(query) if query

              if (search_type && search_terms) || @url
                # warn "Searching #{search_type} for #{search_terms}"

                @search_count += 1
                @url, title, @link_text = do_search(search_type, search_terms, @link_text, @search_count)

                if (@link_text == "" || @link_text == "%") && @url
                  if title
                    @link_text = title
                  else
                    add_title(@url)
                  end
                end

                if @url
                  res = confirmed?(@url)
                  return match unless res

                  @url = res if res.is_a?(String) && SL::URL.url?(res)

                  title = SL::URL.title(@url) if SL.titleize && title == ""

                  @link_text = title if @link_text == "" && title
                  force_title = search_type =~ /def/ ? true : false

                  if link_only || search_type =~ /sp(ell)?/ || @url == "embed"
                    @url = title if @url == "embed"
                    @cursor_difference += SL.match_length - @url.length
                    SL.match_length = @url.length
                    SL.add_report("#{@match_string} => #{@url}")
                    @url
                  elsif @ref_title
                    unless @links.key? @url
                      @links[@url] = @link_text
                      SL.add_footer SL.make_link(:ref_title, @link_text, @url, title: title, force_title: force_title)
                    end
                    @delete_line = true
                  elsif SL.config["inline"]
                    res = SL.make_link(:inline, @link_text, @url, title: title, force_title: force_title)
                    @cursor_difference += SL.match_length - res.length
                    SL.match_length = res.length
                    SL.add_report("#{@match_string} => #{@url}")
                    res
                  else
                    unless @links.key? @url
                      @highest_marker += 1
                      @links[@url] = format("%<pre>s%<m>04d", pre: @prefix, m: @highest_marker)
                      SL.add_footer SL.make_link(:ref_title, @links[@url], @url, title: title, force_title: force_title)
                    end

                    type = SL.config["inline"] ? :inline : :ref_link
                    res = SL.make_link(type, @link_text, @links[@url], title: false, force_title: force_title)
                    @cursor_difference += SL.match_length - res.length
                    SL.match_length = res.length
                    SL.add_report("#{@match_string} => #{@url}")
                    res
                  end
                else
                  SL.add_error("No results", "#{search_terms} (#{@match_string})")
                  counter_errors += 1
                  match
                end
              else
                SL.add_error("Invalid search", match)
                counter_errors += 1
                match
              end
            end
          end
          line_difference += 1 if @delete_line
          out.push(line) unless @delete_line
          @delete_line = false
        end
        warn "\n" unless SILENT

        input = out.delete_if { |l| l.strip =~ /^<!--DELETE-->$/ }.join("\n")

        if SL.config["inline"]
          SL.add_output "#{input}\n"
          SL.add_output "\n#{SL.print_footer}" unless SL.footer.empty?
        elsif SL.footer.empty?
          SL.add_output input
        else
          last_line = input.strip.split(/\n/)[-1]
          case last_line
          when /^\[.*?\]: http/
            SL.add_output "#{input.rstrip}\n"
          when /^\[\^.*?\]: /
            SL.add_output input.rstrip
          else
            SL.add_output "#{input}\n\n"
          end
          SL.add_output "#{SL.print_footer}\n\n"
        end

        SL.line_num = nil
        SL.add_report("Processed: #{total_links} links, #{counter_errors} errors.")
        SL.print_report
        SL.print_errors
      else # Assume single line input
        link_only = false
        SL.clipboard = false

        res = parse_arguments(input.strip!).strip
        input = res.nil? ? input.strip : res
        query, input = input.extract_query({})

        # if the end of input contain "^", copy to clipboard instead of STDOUT
        SL.clipboard = true if input =~ /\^[!~:\s]*$/

        # if the end of input contains "!!", only print the url
        link_only = true if input =~ /!![\^~:\s]*$/

        reference_link = input =~ /:([!\^~\s]*)$/

        # if end of input contains ~, pull url from clipboard
        if input =~ /~[:\^!\s]*$/
          input.sub!(/[:!\^\s~]*$/, "")
          clipboard = `__CF_USER_TEXT_ENCODING=$UID:0x8000100:0x8000100 pbpaste`.strip
          if SL::URL.url?(clipboard)
            type = reference_link ? :ref_title : :inline
            print SL.make_link(type, input.strip, clipboard)
          else
            print SL.originput
          end
          Process.exit
        end

        input.sub!(/[:!\^\s~]*$/, "")

        ## Maybe if input is just a URL, convert it to a link
        ## using hostname as text without doing search
        if SL::URL.only_url?(input.strip)
          type = reference_link ? :ref_title : :inline
          @url, title = SL::URL.url_to_link(input.strip, type)
          print SL.make_link(type, title, @url, title: false, force_title: false)
          Process.exit
        end

        # check for additional search terms in parenthesis
        additional_terms = ""
        if input =~ /\((.*?)\)/
          additional_terms = " #{Regexp.last_match(1).strip}"
          input.sub!(/\(.*?\)/, "")
        end

        # Maybe detect "search + addition terms" and remove additional terms from link text?
        # if input =~ /\+(.+?)$/
        #   additional_terms = "#{additional_terms} #{Regexp.last_match(1).strip}"
        #   input.sub!(/\+.*?$/, '').strip!
        # end

        @link_text = false

        if input =~ /"(.*?)"/
          @link_text = Regexp.last_match(1)
          input.gsub!(/"(.*?)"/, '\1')
        end

        # remove quotes from terms, just in case
        # input.sub!(/^(!\S+)?\s*(["'])(.*?)\2([\!\^]+)?$/, "\\1 \\3\\4")

        case input
        when /^!(\S+)\s+(.*)$/
          type = Regexp.last_match(1).extract_shortener
          link_info = Regexp.last_match(2).strip

          @link_text ||= link_info
          terms = link_info + additional_terms
          terms.strip!

          if SL::Searches.valid_search?(type) || type =~ /^(\S+\.)+\S+$/
            if type && terms && !terms.empty?
              # Iterate through custom searches for a match, perform search if matched
              type, terms = custom_search(type, terms)
            end

            # if contains TLD, use site-specific search
            if type =~ /^(\S+\.)+\S+$/
              terms = "site:#{type} #{terms}"
              type = SL::GoogleSearch.api_key? ? "gg" : "g"
            end
            @search_count ||= 0
            @search_count += 1

            SL.add_query(query) if query
            @url, title, @link_text = do_search(type, terms, @link_text, @search_count)
          else
            SL.add_error("Invalid search#{SL::Searches.did_you_mean(type)}", input)
            counter_errors += 1
          end
          # Social handle expansion
        when /^([tfilm])?@(\S+)\s*$/
          type = Regexp.last_match(1)
          type ||= if Regexp.last_match(2) =~ /[a-z0-9_]@[a-z0-9_.]+/i
              "m"
            else
              "t"
            end
          @link_text = input.sub(/^[tfilm]/, "")
          SL.add_query(query) if query
          @url, title = SL::SocialSearch.social_handle(type, @link_text)
          @link_text = title
        else
          SL.add_query(query) if query
          @link_text ||= input
          @url, title, @link_text = SL.ddg(input, @link_text)
        end

        if @url
          res = confirmed?(@url)
          if res
            if res.is_a?(String) && SL::URL.url?(res)
              @url = res
              title = SL::URL.title(@url) unless title == ""
            end

            if type =~ /sp(ell)?/
              SL.add_output(@url)
            elsif link_only
              SL.add_output(@url)
            elsif @url == "embed"
              SL.add_output(title)
            else
              type = reference_link ? :ref_title : :inline

              SL.add_output SL.make_link(type, @link_text, @url, title: title, force_title: false)
              SL.print_errors
            end
          else
            SL.add_error("Canceled", "User canceled result #{@url}")
            SL.add_output SL.originput.chomp
            SL.print_errors
          end
        else
          SL.add_error("No results", title)
          SL.add_output SL.originput.chomp
          SL.print_errors
        end

        if SL.clipboard
          if SL.output == SL.originput
            warn "No results found"
          else
            `echo #{Shellwords.escape(SL.output.join(""))}|tr -d "\n"|pbcopy`
            warn "Results in clipboard"
          end
        end
      end
    end

    private

    def add_title(link_info)
      @url = link_info
      title = SL::URL.title(@url)
      @link_text = title

      if @ref_title
        unless @links.key? @url
          @links[@url] = @link_text
          SL.add_footer SL.make_link(:ref_title, @link_text, @url, title: title, force_title: false)
        end
        @delete_line = true
      elsif SL.config["inline"]
        res = SL.make_link(:inline, @link_text, @url, title: title, force_title: false)
        @cursor_difference += SL.match_length - res.length
        SL.match_length = res.length
        SL.add_report("#{@match_string} => #{@url}")
        res
      else
        unless @links.key? @url
          @highest_marker += 1
          @links[@url] = format("%<pre>s%<m>04d", pre: @prefix, m: @highest_marker)
          SL.add_footer SL.make_link(:ref_title, @links[@url], @url, title: title, force_title: false)
        end

        type = SL.config["inline"] ? :inline : :ref_link
        res = SL.make_link(type, @link_text, @links[@url], title: false, force_title: false)
        @cursor_difference += SL.match_length - res.length
        SL.match_length = res.length
        SL.add_report("#{@match_string} => #{@url}")
        res
      end
    end

    # Parse arguments in the input string
    #
    # @param      string  [String] the string to parse
    # @param      opt     [Hash] the options to parse
    # @option opt [Boolean] :only_meta (false) whether to skip flags
    # @option opt [Boolean] :no_restore (false) whether to restore previous config
    # @return     [String] the parsed string
    #
    def parse_arguments(string, opt = {})
      input = string.dup
      return "" if input.nil?

      skip_flags = opt[:only_meta] || false
      no_restore = opt[:no_restore] || false
      restore_prev_config unless no_restore

      input.parse_flags! unless skip_flags

      options = %w[debug country_code inline prefix_random include_titles remove_seo validate_links complete_bare
                   confirm]
      options.each do |o|
        if input =~ /^ *#{o}:\s+(\S+)$/
          val = Regexp.last_match(1).strip

          if val.is_a?(String)
            value = true if val =~ /true/i
            value = false if val =~ /false/i
          end
          val = value if value
          SL.config[o] = val
          warn "\r\033[0KGlobal config: #{o} = #{SL.config[o]}\n" unless SILENT
        end

        next if skip_flags

        while input =~ /^#{o}:\s+(.*?)$/ || input =~ /--(no-)?#{o}/
          next unless input =~ /--(no-)?#{o}/ && !skip_flags

          unless SL.prev_config.key? o
            SL.prev_config[o] = SL.config[o]
            bool = Regexp.last_match(1).nil? || Regexp.last_match(1) == "" ? true : false
            SL.config[o] = bool
            $stderr.print "\r\033[0KLine config: #{o} = #{SL.config[o]}\n" unless SILENT
          end
          input.sub!(/\s?--(no-)?#{o}/, "")
        end
      end
      SL.clipboard ? string : input
    end

    # Parse commands from the given input string
    #
    # @param      input  [String] the input string
    def parse_commands(input)
      # Handle commands like help or docs
      return unless input.strip =~ /^!?(h(elp)?|wiki|docs?|v(er(s(ion)?)?)?|up(date|grade))$/

      case input.strip
      when /^!?help$/i
        if SILENT
          help_dialog
        else
          $stdout.puts SL.version_check.to_s
          $stdout.puts "See https://github.com/ttscoff/searchlink/wiki for help"
        end
        print input
      when /^!?(wiki|docs)$/i
        warn "Opening wiki in browser"
        `open https://github.com/ttscoff/searchlink/wiki`
      when /^!?v(er(s(ion)?)?)?$/
        print "[#{SL.version_check}]"
      when /^!?up(date|grade)$/
        SL.update_searchlink
        print SL.output.join("")
      end
      Process.exit 0
    end

    def create_footnote(mtch)
      if mtch[1].nil? || mtch[1] == ""
        match
      else
        note = mtch[1].strip
        @footnote_counter += 1
        ref = if !@link_text.empty? && @link_text.scan(/\s/).empty?
            @link_text
          else
            format("%<p>sfn%<c>04d", p: @prefix, c: @footnote_counter)
          end
        SL.add_footer "[^#{ref}]: #{note}"
        res = "[^#{ref}]"
        @cursor_difference += (SL.match_length - res.length)
        SL.match_length = res.length
        SL.add_report("#{@match_string} => Footnote #{ref}")
        res
      end
    end

    def custom_search(search_type, search_terms)
      SL.config["custom_site_searches"].each do |k, v|
        next unless search_type == k

        @link_text = search_terms if !SL.titleize && @link_text == ""
        v = parse_arguments(v, { no_restore: true })
        query, v = v.extract_query({})

        SL.add_query(query)

        if v =~ %r{^(/|http)}i
          search_type = "r"
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
              remainder = terms_p[highest_token - 1..].join(" ")
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
                re_down = ""
              when /s$/
                replacement.slugify!
                re_down = ""
              else
                re_down = "(?!d|s)"
              end
              v.gsub!(/#{Regexp.escape(t) + re_down}/, replacement.url_encode)
            end
            search_terms = v
          else
            search_terms = v.gsub(/\$term[ds]?/i) do |mtch|
              search_terms.downcase! if mtch =~ /d$/i
              search_terms.slugify! if mtch =~ /s$/i
              search_terms.url_encode
            end
          end
        else
          search_type = SL::GoogleSearch.api_key? ? "gg" : "g"
          search_terms = "site:#{v} #{search_terms}"
        end

        break
      end
      [search_type, search_terms]
    end
  end
end
