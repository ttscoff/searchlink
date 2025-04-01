# frozen_string_literal: true

module SL
  # is.gd link shortening
  class TinyurlSearch
    class << self
      def settings
        {
          trigger: "tiny",
          searches: [
            ["tiny", "TinyURL Shorten"]
          ],
          config: [
            {
              key: "tinyurl_access_token",
              value: "",
              required: true,
              description: "Generate a tinyurl API key at https://tinyurl.ph/developers (login required)"
            }
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
        format_response(url, link, link_text)
      end

      def shorten(url)
        return false unless tinyurl_config?

        headers = {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{SL.config['tinyurl_access_token']}"
        }
        data_obj = {
          "url" => url
        }
        data = Curl::Json.new("https://tinyurl.ph/api/url/add", data: data_obj.to_json, headers: headers,
                                                                symbolize_names: true)

        if data.json[:error].positive?
          SL.add_error("Error creating tinyurl", data.json[:error])
          return false
        end

        data.json[:shorturl]
      end

      def tinyurl_config?
        return true if SL.config["tinyurl_access_token"] && !SL.config["tinyurl_access_token"].empty?

        SL.add_error("TinyURL not configured", "Missing access token")
        false
      end

      def format_response(link, original_url, link_text)
        rtitle = SL::URL.title(original_url)
        [link, rtitle, link_text == "" && !SL.titleize ? rtitle : link_text]
      end
    end

    SL::Searches.register "tiny", :search, self
  end
end
