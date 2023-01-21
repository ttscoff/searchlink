module SL
  class LyricsSearch
    class << self
      def settings
        {
          trigger: 'lyrics?e?',
          searches: [
            ['lyric', 'Song Lyrics Search'],
            ['lyrice', 'Song Lyrics Embed']
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        case search_type
        when /e$/
          url, title = SL.ddg("site:genius.com #{search_terms}", link_text)
          if url
            title = get_lyrics(url)
            title ? ['embed', title, link_text] : false
          else
            SL.add_error('No lyrics found', "Song lyrics for #{search_terms} not found")
            false
          end
        else
          url, title = SSL.ddg("site:genius.com #{search_terms}", link_text)
          [url, title, link_text]
        end
      end

      def get_lyrics(url)
        if SL::URL.valid_link?(url)
          body = `curl -SsL #{url}`

          matches = body.scan(%r{class="Lyrics__Container-.*?>(.*?)</div><div class="RightSidebar})

          lyrics = matches.join("\n")

          if lyrics
            "```\n#{CGI.unescape(lyrics).gsub(%r{<br/?>}, "  \n").gsub(%r{</?.*?>}, '').gsub(/&#x27;/, "'")}\n```"
          else
            false
          end
        else
          false
        end
      end
    end

    SL::Searches.register 'lyrics', :search, self
  end
end
