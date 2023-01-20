module SL
  class SearchLink
    def tmdb(search_type, terms, link_text)
      type = case search_type
             when /t$/
               'tv'
             when /m$/
               'movie'
             when /a$/
               'person'
             else
               'multi'
             end
      body = `/usr/bin/curl -sSL 'https://api.themoviedb.org/3/search/#{type}?query=#{ERB::Util.url_encode(terms)}&api_key=2bd76548656d92517f14d64766e87a02'`
      data = JSON.parse(body)
      if data.key?('results') && data['results'].count.positive?
        res = data['results'][0]
        type = res['media_type'] if type == 'multi'
        id = res['id']
        url = "https://www.themoviedb.org/#{type}/#{id}"
        title = res['name']
        title ||= res['title']
        title ||= terms
      else
        url, title = ddg("site:imdb.com #{terms}")

        return false unless url
      end

      link_text = title if link_text == '' && !@titleize

      [url, title, link_text]
    end
  end
end
