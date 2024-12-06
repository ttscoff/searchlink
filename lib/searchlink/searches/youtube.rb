# frozen_string_literal: true

module SL
  # YouTube Search/Linking
  class YouTubeSearch
    YOUTUBE_RX = %r{(?:youtu\.be/|youtube\.com/watch\?v=)?(?<id>[a-z0-9_\-]+)$}i.freeze

    class << self
      def settings
        {
          trigger: "yte?",
          searches: [
            ["yt", "YouTube Search"],
            ["yte", "YouTube Embed"]
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        if SL::URL.url?(search_terms) && search_terms =~ YOUTUBE_RX
          url = search_terms
        elsif search_terms =~ /^[a-z0-9_\-]+$/i
          url = "https://youtube.com/watch?v=#{search_terms}"
        else
          url, title = SL.ddg("site:youtube.com #{search_terms}", link_text)
        end

        url, title = embed_for_url(url) if search_type =~ /e$/

        [url, title]
      end

      def embed_for_url(url)
        return unless url =~ YOUTUBE_RX

        id = Regexp.last_match("id")
        title = [
          %(<iframe width="560" height="315" src="https://www.youtube.com/embed/#{id}"),
          %(title="YouTube video player" frameborder="0"),
          %(allow="accelerometer; autoplay; clipboard-write; encrypted-media;),
          %(gyroscope; picture-in-picture; web-share"),
          %(allowfullscreen></iframe>)
        ].join(" ")
        ["embed", title]
      end
    end

    SL::Searches.register "youtube", :search, self
  end
end
