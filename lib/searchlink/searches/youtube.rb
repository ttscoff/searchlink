module SL
  class YouTubeSearch
    class << self
      def settings
        {
          trigger: 'yte?',
          searches: [
            ['yt', 'YouTube Search'],
            ['yte', 'YouTube Embed']
          ]
        }
      end
      def search(search_type, search_terms, link_text)
        if SL::URL.url?(search_terms) && search_terms =~ %r{(?:youtu\.be/|youtube\.com/watch\?v=)([a-z0-9_\-]+)$}i
          url = search_terms
        else
          url, title = SL.ddg("site:youtube.com #{search_terms}", link_text)
        end

        if search_type =~ /e$/ && url =~ %r{(?:youtu\.be/|youtube\.com/watch\?v=)([a-z0-9_\-]+)$}i
          id = Regexp.last_match(1)
          url = 'embed'
          title = [
            %(<iframe width="560" height="315" src="https://www.youtube.com/embed/#{id}"),
            %(title="YouTube video player" frameborder="0"),
            %(allow="accelerometer; autoplay; clipboard-write; encrypted-media;),
            %(gyroscope; picture-in-picture; web-share"),
            %(allowfullscreen></iframe>)
          ].join(' ')
        end

        [url, title]
      end
    end

    SL::Searches.register 'youtube', :search, self
  end
end
