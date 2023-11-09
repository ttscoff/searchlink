module SL
  class LastFMSearch
    class << self
      def settings
        {
          trigger: 'l(art|song)',
          searches: [
            ['lart', 'Last.fm Artist Search'],
            ['lsong', 'Last.fm Song Search']
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        type = search_type =~ /art$/ ? 'artist' : 'track'

        url = "http://ws.audioscrobbler.com/2.0/?method=#{type}.search&#{type}=#{search_terms.url_encode}&api_key=2f3407ec29601f97ca8a18ff580477de&format=json"
        json = JSONCurl.new(url).json
        return false unless json['results']

        begin
          case type
          when 'track'
            result = json['results']['trackmatches']['track'][0]
            url = result['url']
            title = "#{result['name']} by #{result['artist']}"
          when 'artist'
            result = json['results']['artistmatches']['artist'][0]
            url = result['url']
            title = result['name']
          end
          [url, title, link_text]
        rescue StandardError
          false
        end
      end
    end

    SL::Searches.register 'lastfm', :search, self
  end
end
