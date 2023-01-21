module SL
  class SearchLink
    def software(search_type, search_terms, link_text)
      excludes = %w[apple.com postmates.com download.cnet.com softpedia.com softonic.com macupdate.com]
      search_url = %(#{excludes.map { |x| "-site:#{x}" }.join(' ')} #{search_terms} app)

      url, title = ddg(search_url)
      link_text = title if link_text == '' && !SL.titleize

      [url, title, link_text]
    end
  end
end
