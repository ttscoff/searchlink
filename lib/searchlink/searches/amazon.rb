module SL
  class SearchLink
    def amazon(search_terms)
      az_url, = ddg("site:amazon.com #{search_terms}")
      url, title = amazon_affiliatize(az_url, @cfg['amazon_partner'])
      title ||= search_terms

      [url, title]
    end
  end
end
