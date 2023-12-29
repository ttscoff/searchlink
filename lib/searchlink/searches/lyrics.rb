# Always start with module SL
module SL
  # Give it a unique class name
  class LyricsSearch
    class << self
      # Settings block is required with `trigger` and `searches`
      def settings
        {
          # `trigger` is A regular expression that will trigger this plugin
          # when used with a bang. The one below will trigger on !lyrics or
          # !lyricse.
          trigger: 'lyrics?(e|e?js)?',
          # Every search that the plugin should execute should be individually
          # listed and described in the searches array. This is used for
          # completion and help generation. Do not include the bang (!) in the
          # search keyword.
          searches: [
            ['lyric', 'Song Lyrics Search'],
            ['lyrice', 'Song Lyrics Embed'],
            ['lyricjs', 'Song Lyrics JS Embed']
          ]
        }
      end

      # Every plugin must contain a #search method that takes 3 arguments:
      #
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
            # To return an embed, set url (first parameter in the return
            # array) to 'embed', and put the embed contents in the second
            # parameter.
            title ? ['embed', title, link_text] : false
          else
            # Use `SL#add_error(title, text)` to add errors to the HTML
            # report. The report will only be shown if errors have been added.
            SL.add_error('No lyrics found', "Song lyrics for #{search_terms} not found")
            false
          end
        when /js$/
          url, title = SL.ddg("site:genius.com #{search_terms}", link_text)
          if url
            title = js_embed(url)
            title ? ['embed', title, link_text] : false
          else
            SL.add_error('No lyrics found', "Song lyrics for #{search_terms} not found")
            false
          end
        else
          # You can perform a DuckDuckGo search using SL#ddg, passing the
          # search terms and link_text. It will return url, title, and
          # link_text. SL#ddg will add its own errors, and if it returns false
          # that will automatically be tested for, no additional error
          # handling is required.
          url, title, link_text = SL.ddg("site:genius.com #{search_terms}", link_text)
          # Always return an array containing the resulting URL, the title,
          # and the link_text variable that was passed in, even if it's
          # unmodified.
          [url, title, link_text]
        end
      end

      def js_embed(url)
        if SL::URL.valid_link?(url)
          body = Curl::Html.new(url).body
          api_path = body.match(%r{\\"apiPath\\":\\"/songs/(.*?)\\"})[1]
          id = api_path.sub(/.*?(\d+)$/, '\1')
          title = body.match(/_sf_async_config.title = '(.*?) \| Genius Lyrics'/)[1]

          <<~EOEMBED
            <div id='rg_embed_link_#{id}' class='rg_embed_link' data-song-id='#{id}'>
            Read <a href='#{url}'>#{title}</a> on Genius
            </div>
            <script crossorigin src='//genius.com#{api_path}/embed.js'></script>
          EOEMBED
        else
          false
        end
      end

      # Any additional helper methods can be defined after #search
      def get_lyrics(url)
        if SL::URL.valid_link?(url)
          # You can use Ruby's net/http methods for retrieving pages, but
          # `curl -SsL` is faster and easier. Curl::Html.new(url) returns a
          # new object containing :body
          body = Curl::Html.new(url).body
          title = body.match(/_sf_async_config.title = '(.*?) \| Genius Lyrics'/)[1].gsub(/\\/, '').sub(/ Lyrics$/, '')
          matches = body.scan(%r{class="Lyrics__Container-.*?>(.*?)</div><div class="LyricsFooter})

          lyrics = matches.join("\n")

          if lyrics
            lyrics = CGI.unescape(lyrics).gsub(%r{<br/?>}, "  \n").gsub(%r{</?.*?>}, '').gsub(/&#x27;/, "'")
            "#{title}\n\n#{lyrics.code_indent}\n"
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
