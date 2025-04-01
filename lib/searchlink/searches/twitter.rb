# frozen_string_literal: true

module SL
  class TwitterSearch
    class << self
      def settings
        {
          trigger: "te",
          searches: [
            ["te", "Twitter Embed"]
          ]
        }
      end

      def search(_search_type, search_terms, link_text)
        if SL::URL.url?(search_terms) && search_terms =~ %r{^https://twitter.com/}
          url, title = twitter_embed(search_terms)
        else
          SL.add_error("Invalid Tweet URL", "#{search_terms} is not a valid link to a tweet or timeline")
          url = false
          title = false
        end

        [url, title, link_text]
      end

      def twitter_embed(tweet)
        res = `curl -sSL 'https://publish.twitter.com/oembed?url=#{tweet.url_encode}'`.strip
        return [false, "Error retrieving tweet"] unless res

        begin
          json = JSON.parse(res)
          url = "embed"
          title = json["html"]
        rescue StandardError
          SL.add_error("Tweet Error", "Error retrieving tweet")
          url = false
          title = tweet
        end

        [url, title]
      end
    end

    SL::Searches.register "twitter", :search, self
  end
end
