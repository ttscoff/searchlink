module SL
  # Bit.ly link shortening
  class BitlySearch
    class << self
      def settings
        {
          trigger: 'b(l|itly)',
          searches: [
            ['bl', 'bit.ly Shorten'],
            ['bitly', 'bit.ly shorten']
          ]
        }
      end

      def search(_, search_terms, link_text)
        if SL::URL.url?(search_terms)
          link = search_terms
        else
          link, rtitle = SL.ddg(search_terms, link_text)
        end

        url, title = bitly_shorten(link, rtitle)
        link_text = title || url
        [url, title, link_text]
      end

      def bitly_shorten(url, title = nil)
        unless SL.config.key?('bitly_access_token') && !SL.config['bitly_access_token'].empty?
          SL.add_error('Bit.ly not configured', 'Missing access token')
          return [false, title]
        end

        domain = SL.config.key?('bitly_domain') ? SL.config['bitly_domain'] : 'bit.ly'
        long_url = url.dup
        curl = TTY::Which.which('curl')
        cmd = [
          %(#{curl} -SsL -H 'Authorization: Bearer #{SL.config['bitly_access_token']}'),
          %(-H 'Content-Type: application/json'),
          '-X POST', %(-d '{ "long_url": "#{url}", "domain": "#{domain}" }'), 'https://api-ssl.bitly.com/v4/shorten'
        ]
        data = JSON.parse(`#{cmd.join(' ')}`.strip)
        link = data['link']
        title ||= SL::URL.title(long_url)
        [link, title]
      end
    end

    SL::Searches.register 'bitly', :search, self
  end
end
