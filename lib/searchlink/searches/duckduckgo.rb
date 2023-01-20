module SL
  class SearchLink
    def ddg(terms, type = false)
      prefix = type ? "#{type.sub(/^!?/, '!')} " : '%5C'
      begin
        cmd = %(/usr/bin/curl -LisS --compressed 'https://lite.duckduckgo.com/lite/?q=#{prefix}#{ERB::Util.url_encode(terms)}')
        body = `#{cmd}`
        locs = body.force_encoding('utf-8').scan(/^location: (.*?)$/)
        return false if locs.empty?

        url = locs[-1]

        result = url[0].strip || false
        return false unless result

        # output_url = CGI.unescape(result)
        output_url = result

        output_title = if @cfg['include_titles'] || @titleize
                         titleize(output_url) || ''
                       else
                         ''
                       end
        [output_url, output_title]
      end
    end

    def zero_click(terms)
      url = URI.parse("http://api.duckduckgo.com/?q=#{ERB::Util.url_encode(terms)}&format=json&no_redirect=1&no_html=1&skip_disambig=1")
      res = Net::HTTP.get_response(url).body
      res = res.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9

      result = JSON.parse(res)
      return ddg(terms) unless result

      wiki_link = result['AbstractURL'] || result['Redirect']
      title = result['Heading'] || false

      if !wiki_link.empty? && !title.empty?
        [wiki_link, title]
      else
        ddg(terms)
      end
    end
  end
end
