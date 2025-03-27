# frozen_string_literal: true

module SL
  # Bit.ly link shortening
  class BitlySearch
    class << self
      def settings
        {
          trigger: "b(l|itly)",
          searches: [
            ["bl", "bit.ly Shorten"],
            ["bitly", "bit.ly shorten"]
          ],
          config: [
            {
              key: "bitly_access_token",
              value: "",
              required: true,
              description: "Generate an access token at https://app.bitly.com/settings/api/"
            },
            {
              description: "Bit.ly domain (optional).",
              key: "bitly_domain",
              value: "bit.ly",
              required: false
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

        unless url
          SL.add_error("Result is not a valid URL", "URL error")
          return [false, title, link_text]
        end

        format_response(url, link, link_text)
      end

      def shorten(url)
        return false unless bitly_config?

        domain = SL.config.key?("bitly_domain") ? SL.config["bitly_domain"] : "bit.ly"
        url.dup

        headers = {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{SL.config['bitly_access_token']}"
        }
        data_obj = {
          "long_url" => url,
          "domain" => domain
        }
        data = Curl::Json.new("https://api-ssl.bitly.com/v4/shorten", data: data_obj.to_json, headers: headers, symbolize_names: true)

        return false unless data.json.key?(:link)

        link = data.json[:link]

        return false unless SL::URL.valid_link?(link)

        link
      end

      private

      def bitly_config?
        return true if SL.config["bitly_access_token"] && !SL.config["bitly_access_token"].empty?

        SL.add_error("Bit.ly not configured", "Missing access token")
        false
      end

      def format_response(link, original_url, link_text)
        rtitle = SL::URL.title(original_url)
        [link, rtitle, link_text == "" && !SL.titleize ? rtitle : link_text]
      end
    end

    SL::Searches.register "bitly", :search, self
  end
end
