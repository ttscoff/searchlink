module SL
  class SearchLink
    def bitly(search_type, search_terms)
      if url?(search_terms)
        link = search_terms
      else
        link, rtitle = ddg(search_terms)
      end

      url, title = bitly_shorten(link, rtitle)
      link_text = title ? title : url
      [url, title, link_text]
    end

    def bitly_shorten(url, title = nil)
      unless @cfg.key?('bitly_access_token') && !@cfg['bitly_access_token'].empty?
        add_error('Bit.ly not configured', 'Missing access token')
        return [false, title]
      end

      domain = @cfg.key?('bitly_domain') ? @cfg['bitly_domain'] : 'bit.ly'
      cmd = [
        %(curl -SsL -H 'Authorization: Bearer #{@cfg['bitly_access_token']}'),
        %(-H 'Content-Type: application/json'),
        '-X POST', %(-d '{ "long_url": "#{url}", "domain": "#{domain}" }'), 'https://api-ssl.bitly.com/v4/shorten'
      ]
      data = JSON.parse(`#{cmd.join(' ')}`.strip)
      link = data['link']
      title ||= @titleize ? titleize(url) : 'Bit.ly Link'
      [link, title]
    end
  end
end
