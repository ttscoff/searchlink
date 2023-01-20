module SL
  class SearchLink
    def wiki(terms)
      ## Hack to scrape wikipedia result
      body = `/usr/bin/curl -sSL 'https://en.wikipedia.org/wiki/Special:Search?search=#{ERB::Util.url_encode(terms)}&go=Go'`
      return unless body

      body = body.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9

      begin
        title = body.match(/"wgTitle":"(.*?)"/)[1]
        url = body.match(/<link rel="canonical" href="(.*?)"/)[1]
      rescue StandardError
        return false
      end

      [url, title]

      ## Removed because Ruby 2.0 does not like https connection to wikipedia without using gems?
      # uri = URI.parse("https://en.wikipedia.org/w/api.php?action=query&format=json&prop=info&inprop=url&titles=#{CGI.escape(terms)}")
      # req = Net::HTTP::Get.new(uri.path)
      # req['Referer'] = "http://brettterpstra.com"
      # req['User-Agent'] = "SearchLink (http://brettterpstra.com)"

      # res = Net::HTTP.start(uri.host, uri.port,
      #   :use_ssl => true,
      #   :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
      #     https.request(req)
      #   end

      # if RUBY_VERSION.to_f > 1.9
      #   body = res.body.force_encoding('utf-8')
      # else
      #   body = res.body
      # end

      # result = JSON.parse(body)

      # if result
      #   result['query']['pages'].each do |page,info|
      #     unless info.key? "missing"
      #       return [info['fullurl'],info['title']]
      #     end
      #   end
      # end
      # return false
    end
  end
end
