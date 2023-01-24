# title: Apple Music Search
# description: Search Apple Music
module SL
  class AppleMusicSearch
    class << self
      def settings
        {
          trigger: 'am(pod|art|alb|song)?e?',
          searches: [
            ['am', 'Apple Music'],
            ['ampod', 'Apple Music Podcast'],
            ['amart', 'Apple Music Artist'],
            ['amalb', 'Apple Music Album'],
            ['amsong', 'Apple Music Song'],
            ['amalbe', 'Apple Music Album Embed'],
            ['amsong', 'Apple Music Song Embed']
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        stype = search_type.downcase.sub(/^am/, '')
        otype = 'link'
        if stype =~ /e$/
          otype = 'embed'
          stype.sub!(/e$/, '')
        end
        result = case stype
                 when /^pod$/
                   applemusic(search_terms, 'podcast')
                 when /^art$/
                   applemusic(search_terms, 'music', 'musicArtist')
                 when /^alb$/
                   applemusic(search_terms, 'music', 'album')
                 when /^song$/
                   applemusic(search_terms, 'music', 'musicTrack')
                 else
                   applemusic(search_terms)
                 end

        return [false, "Not found: #{search_terms}", link_text] unless result

        # {:type=>,:id=>,:url=>,:title=>}
        if otype == 'embed' && result[:type] =~ /(album|song)/
          url = 'embed'
          if result[:type] =~ /song/
            link = %(https://embed.music.apple.com/#{SL.config['country_code'].downcase}/album/#{result[:album]}?i=#{result[:id]}&app=music#{SL.config['itunes_affiliate']})
            height = 150
          else
            link = %(https://embed.music.apple.com/#{SL.config['country_code'].downcase}/album/#{result[:id]}?app=music#{SL.config['itunes_affiliate']})
            height = 450
          end

          title = [
            %(<iframe src="#{link}" allow="autoplay *; encrypted-media *;"),
            %(frameborder="0" height="#{height}"),
            %(style="width:100%;max-width:660px;overflow:hidden;background:transparent;"),
            %(sandbox="allow-forms allow-popups allow-same-origin),
            %(allow-scripts allow-top-navigation-by-user-activation"></iframe>)
          ].join(' ')
        else
          url = result[:url]
          title = result[:title]
        end
        [url, title, link_text]
      end

      # Search apple music
      # terms => search terms (unescaped)
      # media => music, podcast
      # entity => optional: artist, song, album, podcast
      # returns {:type=>,:id=>,:url=>,:title}
      def applemusic(terms, media = 'music', entity = '')
        aff = SL.config['itunes_affiliate']
        output = {}

        url = URI.parse("http://itunes.apple.com/search?term=#{terms.url_encode}&country=#{SL.config['country_code']}&media=#{media}&entity=#{entity}")
        res = Net::HTTP.get_response(url).body
        res = res.force_encoding('utf-8') if RUBY_VERSION.to_f > 1.9
        res.gsub!(/(?mi)[\x00-\x08\x0B-\x0C\x0E-\x1F]/, '')
        json = JSON.parse(res)
        return false unless json['resultCount']&.positive?

        result = json['results'][0]

        case result['wrapperType']
        when 'track'
          if result['kind'] == 'podcast'
            output[:type] = 'podcast'
            output[:id] = result['collectionId']
            output[:url] = result['collectionViewUrl'].to_am + aff
            output[:title] = result['collectionName']
          else
            output[:type] = 'song'
            output[:album] = result['collectionId']
            output[:id] = result['trackId']
            output[:url] = result['trackViewUrl'].to_am + aff
            output[:title] = "#{result['trackName']} by #{result['artistName']}"
          end
        when 'collection'
          output[:type] = 'album'
          output[:id] = result['collectionId']
          output[:url] = result['collectionViewUrl'].to_am + aff
          output[:title] = "#{result['collectionName']} by #{result['artistName']}"
        when 'artist'
          output[:type] = 'artist'
          output[:id] = result['artistId']
          output[:url] = result['artistLinkUrl'].to_am + aff
          output[:title] = result['artistName']
        end
        return false if output.empty?

        output
      end
    end

    SL::Searches.register 'applemusic', :search, self
  end
end
