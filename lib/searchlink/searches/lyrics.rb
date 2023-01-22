module SL
  # Unique class name
  class LyricsSearch
    class << self
      def settings
        {
          # A regular expression that will trigger this plugin when used with
          # a bang. The one below will trigger on !lyrics or !lyricse.
          trigger: 'lyrics?e?',
          # Every search that the plugin should do should be individually
          # listed and described in the searches array. This is used for
          # completion and help generation.
          searches: [
            ['lyric', 'Song Lyrics Search'],
            ['lyrice', 'Song Lyrics Embed']
          ]
        }
      end

      # Every plugin must contain a #search method that takes 3 arguments,
      # search_type, search_terms, and link_text.
      # - `search_type` will contain the !search trigger that was used (minus the !)
      # - `search_terms` will include everything that came after the !search
      # - `link_text` will contain the text that will be used for the linked
      # text portion of the link. This can usually remain untouched but must
      # be passed back at the end of the function.
      def search(search_type, search_terms, link_text)
        # You can branch to multiple searches by testing the search_type
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

      # Any additional helper methods can be defined after #search
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

    # At the end of the search class, you must register it as a plugin. This
    # method takes a title, a type (:search for a search plugin), and the
    # unique class. When running #register within the search class itself,
    # you can just use `self`.
    SL::Searches.register 'lyrics', :search, self
  end
end
