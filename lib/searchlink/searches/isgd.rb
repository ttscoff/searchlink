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
          link, rtitle = SL.ddg(search_terms, link_text)
        end

        url, title = isgd_shorten(link, rtitle)
        link_text = title || url
        [url, title, link_text]
      end

      def isgd_shorten(url, title = nil)
        long_url = url.dup

        data = Curl::Json.new("https://is.gd/create.php?format=json&url=#{CGI.escape(long_url)}", symbolize_names: true)

        if data.json.key?('errorcode')
          SL.add_error('Error creating is.gd url', data.json[:errorcode])
          return [false, title, link_text]
        end

        link = data.json[:shorturl]
        rtitle = SL::URL.title(long_url)
        title = rtitle
        link_text = rtitle if link_text == '' && !SL.titleize
        [link, title, link_text]
      end
    end

    SL::Searches.register "isgd", :search, self
  end
end
