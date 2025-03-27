# frozen_string_literal: true

module SL
  # is.gd link shortening
  class IsgdSearch
    class << self
      def settings
        {
          trigger: "isgd",
          searches: [
            ["isgd", "is.gd Shorten"]
          ]
        }
      end

      def search(_, search_terms, link_text)
        if SL::URL.url?(search_terms)
          link = search_terms
        else
          link, title, link_text = SL.ddg(search_terms, link_text)
        end

        url = shorten(link)
        title = SL::URL.title(link) if title.nil? || title.empty?
        link_text = title if (link_text.nil? || link_text.empty?) && !SL.titleize
        [url, title, link_text]
      end

      def shorten(url)
        long_url = url.dup

        data = Curl::Json.new("https://is.gd/create.php?format=json&url=#{CGI.escape(long_url)}", symbolize_names: true)

        if data.json.key?("errorcode")
          SL.add_error("Error creating is.gd url", data.json[:errorcode])
          return false
        end

        data.json[:shorturl]
      end
    end

    SL::Searches.register "isgd", :search, self
  end
end
