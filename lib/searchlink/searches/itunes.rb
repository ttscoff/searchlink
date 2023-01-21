# title: iTunes Search
# description: Search iTunes
module SL
  class ITunesSearch
    class << self
      def settings
        {
          trigger: '(i(pod|art|alb|song|tud?)|masd?)',
          searches: [
            ['ipod', 'iTunes podcast'],
            ['iart', 'iTunes artist'],
            ['ialb', 'iTunes album'],
            ['isong', 'iTunes song'],
            ['itu', 'iOS App Store Search'],
            ['itud', 'iOS App Store Developer Link'],
            ['mas', 'Mac App Store Search'],
            ['masd', 'Mac App Store Developer Link']
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        case search_type
        when /^ialb$/ # iTunes Album Search
          url, title = search_itunes('album', search_terms, false)
        when /^iart$/ # iTunes Artist Search
          url, title = search_itunes('musicArtist', search_terms, false)
        when /^imov?$/ # iTunes movie search
          dev = false
          url, title = search_itunes('movie', search_terms, dev, SL.config['itunes_affiliate'])
        when /^ipod$/
          url, title = search_itunes('podcast', search_terms, false)
        when /^isong$/ # iTunes Song Search
          url, title = search_itunes('song', search_terms, false)
        when /^itud?$/ # iTunes app search
          dev = search_type =~ /d$/
          url, title = search_itunes('iPadSoftware', search_terms, dev, SL.config['itunes_affiliate'])
        when /^masd?$/ # Mac App Store search (mas = itunes link, masd = developer link)
          dev = search_type =~ /d$/
          url, title = search_itunes('macSoftware', search_terms, dev, SL.config['itunes_affiliate'])
        end

        [url, title, link_text]
      end

      def search_itunes(entity, terms, dev, aff = nil)
        aff ||= SL.config['itunes_affiliate']

        url = URI.parse("http://itunes.apple.com/search?term=#{ERB::Util.url_encode(terms)}&country=#{SL.config['country_code']}&entity=#{entity}&limit=1")

        res = Net::HTTP.get_response(url).body
        res = res.force_encoding('utf-8').encode # if RUBY_VERSION.to_f > 1.9

        begin
          json = JSON.parse(res)
        rescue StandardError => e
          add_error('Invalid response', "Search for #{terms}: (#{e})")
          return false
        end
        return false unless json

        return false unless json['resultCount']&.positive?

        result = json['results'][0]
        case entity
        when /movie/
          # dev parameter probably not necessary in this case
          output_url = result['trackViewUrl']
          output_title = result['trackName']
        when /(mac|iPad)Software/
          output_url = dev && result['sellerUrl'] ? result['sellerUrl'] : result['trackViewUrl']
          output_title = result['trackName']
        when /(musicArtist|song|album)/
          case result['wrapperType']
          when 'track'
            output_url = result['trackViewUrl']
            output_title = "#{result['trackName']} by #{result['artistName']}"
          when 'collection'
            output_url = result['collectionViewUrl']
            output_title = "#{result['collectionName']} by #{result['artistName']}"
          when 'artist'
            output_url = result['artistLinkUrl']
            output_title = result['artistName']
          end
        when /podcast/
          output_url = result['collectionViewUrl']
          output_title = result['collectionName']
        end
        return false unless output_url && output_title

        return [output_url, output_title] if dev

        [output_url + aff, output_title]
      end
    end

    SL::Searches.register 'itunes', :search, self
  end
end
