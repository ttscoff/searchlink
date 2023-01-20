module SL
  # main SearchLink class
  class SearchLink
    ##
    ## search lastfm
    ##
    ## @param      search_type   [String] type of search
    ##                           (track, artist)
    ## @param      search_terms  [String] The search terms
    ##
    ## @return     [Array] [Url, Title]
    ##
    def lastfm(search_type, search_terms)
      url = URI.parse("http://ws.audioscrobbler.com/2.0/?method=#{search_type}.search&#{search_type}=#{ERB::Util.url_encode(search_terms)}&api_key=2f3407ec29601f97ca8a18ff580477de&format=json")
      res = Net::HTTP.get_response(url).body
      res = res.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9
      json = JSON.parse(res)
      return false unless json['results']

      begin
        case search_type
        when 'track'
          result = json['results']['trackmatches']['track'][0]
          url = result['url']
          title = "#{result['name']} by #{result['artist']}"
        when 'artist'
          result = json['results']['artistmatches']['artist'][0]
          url = result['url']
          title = result['name']
        end
        [url, title]
      rescue StandardError
        false
      end
    end
  end
end
