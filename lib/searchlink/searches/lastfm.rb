module SL
  class SearchLink
    def lastfm(entity, terms)
      url = URI.parse("http://ws.audioscrobbler.com/2.0/?method=#{entity}.search&#{entity}=#{ERB::Util.url_encode(terms)}&api_key=2f3407ec29601f97ca8a18ff580477de&format=json")
      res = Net::HTTP.get_response(url).body
      res = res.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9
      json = JSON.parse(res)
      return false unless json['results']

      begin
        case entity
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
