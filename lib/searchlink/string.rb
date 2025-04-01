# frozen_string_literal: true

module SL
  # String helpers
  class ::String
    # Quote a YAML value if needed
    def yaml_val
      yaml = YAML.safe_load("key: '#{self}'")
      YAML.dump(yaml).match(/key: (.*?)$/)[1]
    end

    # Word wrap a string not exceeding max width.
    # CREDIT: Gavin Kistner, Dayne Broderson
    #
    def word_wrap!(col_width = 60, prefix = "")
      replace dup.word_wrap(col_width, prefix)
    end

    # As with #word_wrap, but modifies the string in place.
    #
    # CREDIT: Gavin Kistner, Dayne Broderson
    #
    def word_wrap(col_width = 60, prefix = "")
      str = dup
      str.gsub!(/(\S{#{col_width}})(?=\S)/, "#{prefix}\\1")
      str.gsub!(/(.{1,#{col_width}})(?:\s+|$)/, "#{prefix}\\1\n")
      str
    end

    # Scrub invalid characters from string
    def scrubup
      encode("utf-16", invalid: :replace).encode("utf-8").gsub(/\u00A0/, " ")
    end

    # @see #scrub
    def scrubup!
      replace scrub
    end

    # Extract query string from search string
    def extract_query(known_queries = {})
      string = gsub(/\?((\S+?)=(\S+?)(?=&|$|\s))+/) do |mtch|
        tokens = mtch.sub(/^\?/, "").split("&")
        tokens.each do |token|
          key, value = token.split("=")

          known_queries[key] = value
        end

        ""
      end.gsub(/ +/, " ").strip

      [known_queries, string]
    end

    # Extract a shortner from a string
    def extract_shortener
      return self unless self =~ /_[ibt]$/i

      shortener = split(/_/).last
      SL.shortener = case shortener
                     when /i/i
                       :isgd
                     when /b/i
                       :bitly
                     when /t/i
                       :tinyurl
                     else
                       :none
                     end

      sub(/_[ibt]$/i, "")
    end

    # Destructive version of #extract_shortener
    # @see #extract_shortener
    # @return     [String] The string without the shortener
    def extract_shortener!
      replace extract_shortener
    end

    # Format and append a query string
    #
    # @return     [String] The formatted query string
    #
    def add_query_string
      return self if SL.query.empty?

      query = SL.query.map { |k, v| "#{k}=#{v}" }.join("&")

      query = if self =~ /\?[^= ]+=\S+/
                "&#{query}"
              else
                "?#{query}"
              end

      "#{self}#{query}"
    end

    # Destructive version of #add_query_string
    # @see #add_query_string
    # @return     [String] The formatted query string
    def add_query_string!
      replace add_query_string
    end

    # URL Encode string
    #
    # @return     [String] url encoded string
    #
    def url_encode
      ERB::Util.url_encode(gsub(/%22/, '"'))
    end

    def url_decode
      CGI.unescape(self)
    end

    ##
    ## Adds ?: to any parentheticals in a regular expression
    ## to avoid match groups
    ##
    ## @return     [String] modified regular expression
    ##
    def normalize_trigger
      gsub(/\((?!\?:)/, "(?:").gsub(/(^(\^|\\A)|(\$|\\Z)$)/, "").downcase
    end

    ##
    ## Generate a spacer based on character widths for help dialog display
    ##
    ## @return     [String] string containing tabs
    ##
    def spacer
      len = length
      scan(/[mwv]/).each { len += 1 }
      scan(/t/).each { len -= 1 }
      case len
      when 0..3
        "\t\t"
      when 4..12
        " \t"
      end
    end

    # parse command line flags into long options
    def parse_flags
      gsub(/(\+\+|--)([dirtvsc]+)\b/) do
        m = Regexp.last_match
        bool = m[1] == "++" ? "" : "no-"
        output = " "
        m[2].split("").each do |arg|
          output += case arg
                    when "c"
                      "--#{bool}confirm"
                    when "d"
                      "--#{bool}debug "
                    when "i"
                      "--#{bool}inline "
                    when "r"
                      "--#{bool}prefix_random "
                    when "t"
                      "--#{bool}include_titles "
                    when "v"
                      "--#{bool}validate_links "
                    when "s"
                      "--#{bool}remove_seo "
                    else
                      ""
                    end
        end

        output
      end.gsub(/ +/, " ")
    end

    def parse_flags!
      replace parse_flags
    end

    ##
    ## Convert file-myfile-rb to myfile.rb
    ##
    ## @return     { description_of_the_return_value }
    ##
    def fix_gist_file
      sub(/^file-/, "").sub(/-([^-]+)$/, '.\1')
    end

    # Turn a string into a slug, removing spaces and
    # non-alphanumeric characters
    #
    # @return     [String] slugified string
    #
    def slugify
      downcase.gsub(/[^a-z0-9_]/i, "-").gsub(/-+/, "-").sub(/-?$/, "")
    end

    # Destructive slugify
    # @see #slugify
    def slugify!
      replace slugify
    end

    ##
    ## Remove newlines, escape quotes, and remove Google
    ## Analytics strings
    ##
    ## @return     [String] cleaned URL/String
    ##
    def clean
      gsub(/\n+/, " ")
        .gsub(/"/, "&quot")
        .gsub(/\|/, "-")
        .gsub(/([&?]utm_[scm].+=[^&\s!,.)\]]++?)+(&.*)/, '\2')
        .sub(/\?&/, "").strip
    end

    # convert itunes to apple music link
    #
    # @return [String] apple music link
    def to_am
      input = dup
      input.sub!(%r{/itunes\.apple\.com}, "geo.itunes.apple.com")
      append = input =~ %r{\?[^/]+=} ? "&app=music" : "?app=music"
      input + append
    end

    ##
    ## Append an affiliate string to a URL
    ##
    ## @param      aff_string   [String]  The affiliate string
    ## @return     [String]  The URL with the affiliate string
    ##
    ## @see        #append_affiliate_string!
    ##
    def append_affiliate_string(aff_string)
      separator = self =~ /\?/ ? "&" : "?"
      "#{self}#{aff_string.sub(/^[?&]?/, separator)}"
    end

    ## Destructively append an affiliate string to a URL
    ##
    ## @param      aff_string   [String]  The affiliate string
    ## @return     [String]  The URL with the affiliate string
    ##
    ## @see        #append_affiliate_string
    ##
    def append_affiliate_string!(aff_string)
      replace append_affiliate_string(aff_string)
    end

    ##
    ## Remove the protocol from a URL
    ##
    ## @return     [String] just hostname and path of URL
    ##
    def remove_protocol
      sub(%r{^(https?|s?ftp|file)://}, "")
    end

    ##
    ## Return just the path of a URL
    ##
    ## @return     [String] The path.
    ##
    def url_path
      URI.parse(self).path
    end

    # Extract the most relevant portions from a URL path
    #
    # @return     [Array] array of relevant path elements
    #
    def path_elements
      path = url_path
      # force trailing slash
      path.sub!(%r{/?$}, "/")
      # remove last path element
      path.sub!(%r{/[^/]+[.-][^/]+/$}, "")
      # remove starting/ending slashes
      path.gsub!(%r{(^/|/$)}, "")
      # split at slashes, delete sections that are shorter
      # than 5 characters or only consist of numbers
      path.split(%r{/}).delete_if { |section| section =~ /^\d+$/ || section.length < 5 }
    end

    ##
    ## Destructive punctuation close
    ##
    ## @see        #close_punctuation
    ##
    def close_punctuation!
      replace close_punctuation
    end

    ##
    ## Complete incomplete punctuation pairs
    ##
    ## @return     [String] string with all punctuation
    ##             properly paired
    ##
    def close_punctuation
      return self unless self =~ /[“‘\[(<]/

      words = split(/\s+/)

      punct_chars = {
        "“" => "”",
        "‘" => "’",
        "[" => "]",
        "(" => ")",
        "<" => ">"
      }

      left_punct = []

      words.each do |w|
        punct_chars.each do |k, v|
          left_punct.push(k) if w =~ /#{Regexp.escape(k)}/
          left_punct.delete_at(left_punct.rindex(k)) if w =~ /#{Regexp.escape(v)}/
        end
      end

      tail = ""
      left_punct.reverse.each { |c| tail += punct_chars[c] }

      gsub(/[^a-z)\]’”.…]+$/i, "...").strip + tail
    end

    ##
    ## Destructively remove SEO elements from a title
    ##
    ## @param      url   The url of the page from which the
    ##                   title came
    ##
    ## @see        #remove_seo
    ##
    def remove_seo!(url)
      replace remove_seo(url)
    end

    ##
    ## Remove SEO elements from a title
    ##
    ## @param      url   The url of the page from which the title came
    ##
    ## @return     [String] cleaned title
    ##
    def remove_seo(url)
      title = dup
      url = URI.parse(url)
      host = url.hostname
      unless host
        return self unless SL.config["debug"]

        SL.add_error("Invalid URL", "Could not remove SEO for #{url}")
        return self
      end

      path = url.path
      root_page = path =~ %r{^/?$} ? true : false

      title.gsub!(/\s*(&ndash;|&mdash;)\s*/, " - ")
      title.gsub!(/&[lr]dquo;/, '"')
      title.gsub!(/&[lr]dquo;/, "'")
      title.gsub!(/&#8211;/, " — ")
      title = CGI.unescapeHTML(title)
      title.gsub!(/ +/, " ")

      seo_title_separators = %w[| » « — – - · :]

      begin
        re_parts = []

        host_parts = host.sub(/(?:www\.)?(.*?)\.[^.]+$/, '\1').split(/\./).delete_if { |p| p.length < 3 }
        h_re = !host_parts.empty? ? host_parts.map { |seg| seg.downcase.split(//).join(".?") }.join("|") : ""
        re_parts.push(h_re) unless h_re.empty?

        # p_re = path.path_elements.map{|seg| seg.downcase.split(//).join('.?') }.join('|')
        # re_parts.push(p_re) if p_re.length > 0

        site_re = "(#{re_parts.join('|')})"

        dead_switch = 0

        while title.downcase.gsub(/[^a-z]/i, "") =~ /#{site_re}/i
          break if dead_switch > 5

          seo_title_separators.each_with_index do |sep, i|
            parts = title.split(/ *#{Regexp.escape(sep)} +/)

            next if parts.length == 1

            remaining_separators = seo_title_separators[i..].map { |s| Regexp.escape(s) }.join("")
            seps = Regexp.new("^[^#{remaining_separators}]+$")

            longest = parts.longest_element.strip

            unless parts.empty?
              parts.delete_if do |pt|
                compressed = pt.strip.downcase.gsub(/[^a-z]/i, "")
                compressed =~ /#{site_re}/ && pt =~ seps ? !root_page : false
              end
            end

            title = if parts.empty?
                      longest
                    elsif parts.length < 2
                      parts.join(sep)
                    elsif parts.length > 2
                      parts.longest_element.strip
                    else
                      parts.join(sep)
                    end
          end
          dead_switch += 1
        end
      rescue StandardError => e
        return self unless SL.config["debug"]

        SL.add_error("Error SEO processing title for #{url}", e)
        return self
      end

      seps = Regexp.new(" *[#{seo_title_separators.map { |s| Regexp.escape(s) }.join('')}] +")
      if title =~ seps
        seo_parts = title.split(seps)
        title = seo_parts.longest_element.strip if seo_parts.length.positive?
      end

      title && title.length > 5 ? title.gsub(/\s+/, " ") : CGI.unescapeHTML(self)
    end

    ##
    ## Truncate in place
    ##
    ## @see        #truncate
    ##
    ## @param      max   [Number]  The maximum length
    ##
    def truncate!(max)
      replace truncate(max)
    end

    ##
    ## Truncate string to given length, preserving words
    ##
    ## @param      max   [Number]  The maximum length
    ##
    def truncate(max)
      return self if length < max

      trunc_title = []

      words = split(/\s+/)
      words.each do |word|
        break unless trunc_title.join(" ").length.close_punctuation + word.length <= max

        trunc_title << word
      end

      trunc_title.empty? ? words[0] : trunc_title.join(" ")
    end

    ##
    ## Test an AppleScript response, substituting nil for
    ## 'Missing Value'
    ##
    ## @return     [Nil, String] nil if string is
    ##             "missing value"
    ##
    def nil_if_missing
      return nil if self =~ /missing value/

      self
    end

    ##
    ## Score string based on number of matches, 0 - 10
    ##
    ## @param      terms       [String]      The terms to
    ##                         match
    ## @param      separator   [String]  The word separator
    ## @param      start_word  [Boolean] Require match to be
    ##                         at beginning of word
    ##
    def matches_score(terms, separator: " ", start_word: true)
      matched = 0
      regexes = terms.to_rx_array(separator: separator, start_word: start_word)

      regexes.each do |rx|
        matched += 1 if self =~ rx
      end

      return 0 if matched.zero?

      ((matched / regexes.count.to_f) * 10).round(3)
    end

    def matches_fuzzy(terms, separator: " ", start_word: true, threshhold: 5)
      sources = split(/(#{separator})+/)
      words = terms.split(/(#{separator})+/)
      matches = 0
      sources.each do |src|
        words.each do |term|
          d = src.distance(term)
          matches += 1 if d <= threshhold
        end
      end

      ((matches / words.count.to_f) * 10).round(3)
    end

    def distance(t)
      s = dup
      m = s.length
      n = t.length
      return m if n.zero?
      return n if m.zero?

      d = Array.new(m + 1) { Array.new(n + 1) }

      (0..m).each { |i| d[i][0] = i }
      (0..n).each { |j| d[0][j] = j }
      (1..n).each do |j|
        (1..m).each do |i|
          d[i][j] = if s[i - 1] == t[j - 1] # adjust index into string
                      d[i - 1][j - 1] # no operation required
                    else
                      [d[i - 1][j] + 1, # deletion
                       d[i][j - 1] + 1, # insertion
                       d[i - 1][j - 1] + 1 # substitution
        ].min
                    end
        end
      end
      d[m][n]
    end

    ##
    ## Test if self contains exactl match for string (case insensitive)
    ##
    ## @param      string [String] The string to match
    ##
    def matches_exact(string)
      comp = gsub(/[^a-z0-9 ]/i, "")
      comp =~ /\b#{string.gsub(/[^a-z0-9 ]/i, '').split(/ +/).map { |s| Regexp.escape(s) }.join(' +')}/i
    end

    ##
    ## Test that self does not contain any of terms
    ##
    ## @param      terms [String] The terms to test
    ##
    def matches_none(terms)
      rx_terms = terms.is_a?(String) ? terms.to_rx_array : terms
      rx_terms.each { |rx| return false if gsub(/[^a-z0-9 ]/i, "") =~ rx }
      true
    end

    ##
    ## Test if self contains any of terms
    ##
    ## @param      terms [String] The terms to test
    ##
    def matches_any(terms)
      rx_terms = terms.is_a?(String) ? terms.to_rx_array : terms
      rx_terms.each { |rx| return true if gsub(/[^a-z0-9 ]/i, "") =~ rx }
      false
    end

    ##
    ## Test that self matches every word in terms
    ##
    ## @param      terms [String] The terms to test
    ##
    def matches_all(terms)
      rx_terms = terms.is_a?(String) ? terms.to_rx_array : terms
      rx_terms.each { |rx| return false unless gsub(/[^a-z0-9 ]/i, "") =~ rx }
      true
    end

    ##
    ## Break a string into an array of Regexps
    ##
    ## @param      separator   [String]  The word separator
    ## @param      start_word  [Boolean] Require matches at
    ##                         start of word
    ##
    ## @return     [Array] array of regular expressions
    ##
    def to_rx_array(separator: " ", start_word: true)
      bound = start_word ? '\b' : ""
      str = gsub(/(#{separator})+/, separator)
      str.split(/#{separator}/).map { |arg| /#{bound}#{arg.gsub(/[^a-z0-9]/i, '.?')}/i }
    end

    ##
    ## Indent each line of string with 4 spaces
    ##
    ## @return [String] indented string
    def code_indent
      split(/\n/).map { |l| "    #{l}" }.join("\n")
    end

    ##
    ## Shorten path by adding ~ for home directory
    ##
    def shorten_path
      home_directory = ENV["HOME"]
      sub(home_directory, "~")
    end
  end
end
