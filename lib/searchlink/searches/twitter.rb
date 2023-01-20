module SL
  class SearchLink
    def twitter(search_type, search_terms)
      if url?(search_terms) && search_terms =~ %r{^https://twitter.com/}
        url, title = twitter_embed(search_terms)
      else
        add_error('Invalid Tweet URL', "#{search_terms} is not a valid link to a tweet or timeline")
        url = false
        title = false
      end

      [url, title]
    end

    def twitter_embed(tweet)
      res = `curl -sSL 'https://publish.twitter.com/oembed?url=#{ERB::Util.url_encode(tweet)}'`.strip
      if res
        begin
          json = JSON.parse(res)
          url = 'embed'
          title = json['html']
        rescue StandardError
          add_error('Tweet Error', 'Error retrieving tweet')
          url = false
          title = tweet
        end
      else
        return [false, 'Error retrieving tweet']
      end
      return [url, title]
    end
  end
end
