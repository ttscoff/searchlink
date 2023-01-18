# String helpers
class ::String
  def slugify
    downcase.gsub(/[^a-z0-9_]/i, '-').gsub(/-+/, '-')
  end

  def slugify!
    replace slugify
  end

  def clean
    gsub(/\n+/, ' ')
      .gsub(/"/, '&quot')
      .gsub(/\|/, '-')
      .gsub(/([&?]utm_[scm].+=[^&\s!,.)\]]++?)+(&.*)/, '\2')
      .sub(/\?&/, '').strip
  end

  # convert itunes to apple music link
  def to_am
    input = dup
    input.sub!(%r{/itunes\.apple\.com}, 'geo.itunes.apple.com')
    append = input =~ %r{\?[^/]+=} ? '&app=music' : '?app=music'
    input + append
  end

  def path_elements
    path = URI.parse(self).path
    path.sub!(%r{/?$}, '/')
    path.sub!(%r{/[^/]+[.\-][^/]+/$}, '')
    path.gsub!(%r{(^/|/$)}, '')
    path.split(%r{/}).delete_if { |section| section =~ /^\d+$/ || section.length < 5 }
  end

  def close_punctuation!
    replace close_punctuation
  end

  def close_punctuation
    return self unless self =~ /[“‘\[(<]/

    words = split(/\s+/)

    punct_chars = {
      '“' => '”',
      '‘' => '’',
      '[' => ']',
      '(' => ')',
      '<' => '>'
    }

    left_punct = []

    words.each do |w|
      punct_chars.each do |k, v|
        left_punct.push(k) if w =~ /#{Regexp.escape(k)}/
        left_punct.delete_at(left_punct.rindex(k)) if w =~ /#{Regexp.escape(v)}/
      end
    end

    tail = ''
    left_punct.reverse.each { |c| tail += punct_chars[c] }

    gsub(/[^a-z)\]’”.…]+$/i, '...').strip + tail
  end

  def remove_seo!(url)
    replace remove_seo(url)
  end

  def remove_seo(url)
    title = dup
    url = URI.parse(url)
    host = url.hostname
    path = url.path
    root_page = path =~ %r{^/?$} ? true : false

    title.gsub!(/\s*(&ndash;|&mdash;)\s*/, ' - ')
    title.gsub!(/&[lr]dquo;/, '"')
    title.gsub!(/&[lr]dquo;/, "'")

    seo_title_separators = %w[| « - – · :]

    begin
      re_parts = []

      host_parts = host.sub(/(?:www\.)?(.*?)\.[^.]+$/, '\1').split(/\./).delete_if { |p| p.length < 3 }
      h_re = !host_parts.empty? ? host_parts.map { |seg| seg.downcase.split(//).join('.?') }.join('|') : ''
      re_parts.push(h_re) unless h_re.empty?

      # p_re = path.path_elements.map{|seg| seg.downcase.split(//).join('.?') }.join('|')
      # re_parts.push(p_re) if p_re.length > 0

      site_re = "(#{re_parts.join('|')})"

      dead_switch = 0

      while title.downcase.gsub(/[^a-z]/i, '') =~ /#{site_re}/i

        break if dead_switch > 5

        seo_title_separators.each_with_index do |sep, i|
          parts = title.split(/ ?#{Regexp.escape(sep)} +/)

          next if parts.length == 1

          remaining_separators = seo_title_separators[i..-1].map { |s| Regexp.escape(s) }.join('')
          seps = Regexp.new("^[^#{remaining_separators}]+$")

          longest = parts.longest_element.strip

          unless parts.empty?
            parts.delete_if do |pt|
              compressed = pt.strip.downcase.gsub(/[^a-z]/i, '')
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
      return self unless $cfg['debug']
      warn 'Error processing title'
      p e
      raise e
      # return self
    end

    seps = Regexp.new("[#{seo_title_separators.map { |s| Regexp.escape(s) }.join('')}]")
    if title =~ seps
      seo_parts = title.split(seps)
      title = seo_parts.longest_element.strip if seo_parts.length.positive?
    end

    title && title.length > 5 ? title.gsub(/\s+/, ' ') : self
  end

  def truncate!(max)
    replace truncate(max)
  end

  def truncate(max)
    return self if length < max

    max -= 3
    counter = 0
    trunc_title = ''

    words = split(/\s+/)
    while trunc_title.length < max && counter < words.length
      trunc_title += " #{words[counter]}"
      break if trunc_title.length + 1 > max

      counter += 1
    end

    trunc_title = words[0] if trunc_title.nil? || trunc_title.empty?

    trunc_title
  end

  def nil_if_missing
    return nil if self =~ /missing value/

    self
  end

  def split_hook
    elements = split(/\|\|/)
    {
      name: elements[0].nil_if_missing,
      url: elements[1].nil_if_missing,
      path: elements[2].nil_if_missing
    }
  end

  def split_hooks
    split(/\^\^/).map(&:split_hook)
  end

  def matches_score(terms, separator: ' ', start_word: true)
    matched = 0
    regexes = terms.to_rx_array(separator: separator, start_word: start_word)

    regexes.each do |rx|
      matched += 1 if self =~ rx
    end

    (matched / regexes.count.to_f) * 10
  end

  def matches_exact(string)
    comp = gsub(/[^a-z0-9 ]/i, '')
    comp =~ /\b#{string.gsub(/[^a-z0-9 ]/i, '').split(/ +/).map { |s| Regexp.escape(s) }.join(' +')}/i
  end

  def matches_none(terms)
    terms.to_rx_array.each { |rx| return false if gsub(/[^a-z0-9 ]/i, '') =~ rx }
    true
  end

  def matches_any(terms)
    terms.to_rx_array.each { |rx| return true if gsub(/[^a-z0-9 ]/i, '') =~ rx }
    false
  end

  def matches_all(terms)
    terms.to_rx_array.each { |rx| return false unless gsub(/[^a-z0-9 ]/i, '') =~ rx }
    true
  end

  def to_rx_array(separator: ' ', start_word: true)
    bound = start_word ? '\b' : ''
    split(/#{separator}/).map { |arg| /#{bound}#{Regexp.escape(arg.gsub(/[^a-z0-9]/i, ''))}/i }
  end
end
