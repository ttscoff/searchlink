# frozen_string_literal: true

module SL
  # Keenable web search
  class KeenableSearch
    class << self
      # Returns the settings hash for the KeenableSearch plugin.
      #
      # @return [Hash] settings including trigger, searches, and config entries
      #
      def settings
        {
          trigger: "kn",
          searches: [
            ["kn", "Keenable Search"]
          ],
          config: [
            {
              key: "keenable_api_key",
              value: "xxxxxx",
              required: false,
              description: "Keenable API key for web search (see https://keenable.ai)"
            }
          ]
        }
      end

      # Returns true if a usable Keenable API key is configured.
      #
      # @return [Boolean] true when a non-placeholder API key is present
      #
      def api_key?
        return false unless SL.config.key?("keenable_api_key") && SL.config["keenable_api_key"]

        key = SL.config["keenable_api_key"].to_s.strip
        return false if key.empty? || key =~ /^(x{4,})?$/i

        @api_key = key

        true
      end

      # Perform a Keenable web search and return the first result.
      #
      # @param _search_type [String] the search shortcut ("kn")
      # @param search_terms [String] the terms to search for
      # @param link_text [String] the text to display for the link
      #
      # @return [Array] [url, title, link_text] or DuckDuckGo fallback
      #
      def search(_search_type, search_terms, link_text)
        unless api_key?
          SL.notify("Keenable not configured", "Missing Keenable API key, defaulting to DuckDuckGo")
          return SL.ddg(search_terms, link_text, google: false)
        end

        headers = {
          "X-API-Key" => @api_key,
          "X-Keenable-Title" => "SearchLink",
          "Content-Type" => "application/json"
        }
        # Curl::Json passes the body inside single quotes; escape them as JSON.
        body = { query: search_terms.gsub("%22", '"'), max_results: 1 }.to_json.gsub("'", "\\u0027")

        res = Curl::Json.new("https://api.keenable.ai/v1/search", data: body, headers: headers, symbolize_names: true)
        return SL.ddg(search_terms, link_text, google: false) unless res && res.code.to_i == 200 && res.json

        results = res.json[:results]
        first = results.is_a?(Array) ? results.find { |r| r.is_a?(Hash) && r[:url] } : nil
        return SL.ddg(search_terms, link_text, google: false) unless first

        output_url = first[:url]
        output_title = first[:title] || link_text

        if defined?(SL.config) && SL.config.respond_to?(:[]) && output_title && SL.config["remove_seo"]
          output_title.remove_seo!(output_url)
        end

        [output_url, output_title, link_text]
      rescue StandardError => e
        SL.notify("Keenable error", "Error fetching Keenable results, switching to DuckDuckGo")
        SL.add_error("Keenable error", e.message)
        SL.ddg(search_terms, link_text, google: false)
      end
    end

    SL::Searches.register "keenable", :search, self
  end
end
