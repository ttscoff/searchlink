module SL
  class SearchLink
    def youtube(search_type, search_terms)
      if url?(search_terms) && search_terms =~ %r{(?:youtu\.be/|youtube\.com/watch\?v=)([a-z0-9_\-]+)$}i
        url = search_terms
      else
        url, title = ddg("site:youtube.com #{search_terms}")
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
end
