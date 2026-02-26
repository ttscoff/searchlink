# frozen_string_literal: true

module SL
  # Kagi Search and FastGPT
  class KagiSearch
    class << self
      # Returns the settings hash for the KagiSearch plugin.
      #
      # @return [Hash] settings including trigger, searches, and config entries
      #
      def settings
        {
          trigger: "(?:k|gpt)",
          searches: [
            ["k", "Kagi Search"],
            ["gpt", "Kagi FastGPT Embed"]
          ],
          config: [
            {
              key: "kagi_api_key",
              value: "xxxxxx",
              required: false,
              description: "Kagi Bot API key for paid search and FastGPT (see https://kagi.com/settings/api)"
            }
          ]
        }
      end

      # Returns true if a usable Kagi API key is configured.
      #
      # @return [Boolean] true when a non-placeholder API key is present
      #
      def api_key?
        return false unless SL.config.key?("kagi_api_key") && SL.config["kagi_api_key"]

        key = SL.config["kagi_api_key"].to_s.strip
        return false if key.empty? || key =~ /^(x{4,})?$/i

        @api_key = key

        true
      end

      # Perform a Kagi search or FastGPT request.
      #
      # @param search_type [String] the search shortcut ("k" or "gpt")
      # @param search_terms [String] the search terms or FastGPT query
      # @param link_text [String] the link text to display
      #
      # @return [Array] result array suitable for SearchLink: [url_or_embed, title_or_body, link_text]
      #
      def search(search_type, search_terms, link_text)
        case search_type
        when /^k$/
          kagi_search(search_terms, link_text)
        when /^gpt$/
          kagi_fastgpt(search_terms, link_text)
        else
          SL.ddg(search_terms, link_text)
        end
      rescue StandardError => e
        SL.notify("Kagi error", "Error fetching Kagi results, switching to DuckDuckGo")
        SL.add_error("Kagi error", e.message)
        SL.ddg(search_terms, link_text)
      end

      # Perform a Kagi web search for the given terms.
      #
      # @param search_terms [String] the terms to search for
      # @param link_text [String] the text to display for the link
      #
      # @return [Array] [url, title, link_text] or DuckDuckGo fallback
      #
      def kagi_search(search_terms, link_text)
        unless api_key?
          SL.notify("Kagi not configured", "Missing Kagi API key, defaulting to DuckDuckGo")
          return SL.ddg(search_terms, link_text, google: false)
        end

        query = ERB::Util.url_encode(search_terms.gsub("%22", '"'))
        url = "https://kagi.com/api/v0/search?q=#{query}&limit=1"

        headers = {
          "Authorization" => "Bot #{@api_key}"
        }

        res = Curl::Json.new(url, headers: headers, symbolize_names: true)
        return SL.ddg(search_terms, link_text, google: false) unless res && res.code.to_i == 200 && res.json

        data = res.json[:data]
        return SL.ddg(search_terms, link_text, google: false) unless data.is_a?(Array) && data.first.is_a?(Hash)

        first = data.first
        output_url = first[:url]
        output_title = first[:title] || link_text

        return SL.ddg(search_terms, link_text, google: false) unless output_url

        if defined?(SL.config) && SL.config.respond_to?(:[]) && output_title && SL.config["remove_seo"]
          output_title.remove_seo!(output_url)
        end

        [output_url, output_title, link_text]
      rescue StandardError
        SL.notify("Kagi error", "Error fetching Kagi results, switching to DuckDuckGo")
        SL.ddg(search_terms, link_text, google: false)
      end

      # Perform a Kagi FastGPT query and return an embed response.
      #
      # @param search_terms [String] the FastGPT query
      # @param link_text [String] the text to display for the link
      #
      # @return [Array] ["embed", embed_markdown, link_text]
      #
      def kagi_fastgpt(search_terms, link_text)
        return ["embed", fastgpt_fallback(search_terms, "Kagi FastGPT is not configured."), link_text] unless api_key?

        headers = {
          "Authorization" => "Bot #{@api_key}",
          "Content-Type" => "application/json"
        }
        body = { query: search_terms }.to_json

        res = Curl::Json.new("https://kagi.com/api/v0/fastgpt", data: body, headers: headers, symbolize_names: true)
        return ["embed", fastgpt_fallback(search_terms, "Kagi FastGPT request failed."), link_text] unless res && res.code.to_i == 200 && res.json

        data = res.json[:data]
        return ["embed", fastgpt_fallback(search_terms, "Kagi FastGPT response missing data."), link_text] unless data.is_a?(Hash)

        output = data[:output].to_s
        references = data[:references] || []

        embed = build_fastgpt_embed(output, references, search_terms)
        ["embed", embed, link_text]
      rescue StandardError
        ["embed", fastgpt_fallback(search_terms, "Kagi FastGPT encountered an error."), link_text]
      end

      # Build a Markdown embed string from FastGPT output and references.
      #
      # @param output [String] main answer text
      # @param references [Array<Hash>] reference entries with :title, :snippet, and :url
      # @param query [String] original query string
      #
      # @return [String] Markdown-formatted embed content
      #
      def build_fastgpt_embed(output, references, query)
        header = "### Answer for: #{query}\n\n"
        body = clean_fastgpt_output(output.to_s)

        refs_section = ""
        if references.is_a?(Array) && !references.empty?
          lines = references.each_with_index.map do |ref, _idx|
            url = ref[:url] || ref["url"]
            next unless url

            title = ref[:title] || ref["title"] || url
            "- [#{title}](#{url})"
          end.compact

          refs_section = "\n\n**References:**\n#{lines.join("\n")}" unless lines.empty?
        end

        header + body + refs_section
      end

      # Build a fallback embed body when FastGPT is unavailable.
      #
      # @param query [String] the original query
      # @param message [String] description of the failure
      #
      # @return [String] fallback embed content
      #
      def fastgpt_fallback(query, message)
        "### Answer for: #{query}\n\n#{message}"
      end

      # Clean FastGPT output by removing in-text numeric reference markers and
      # normalizing whitespace.
      #
      # @param output [String] raw FastGPT output text
      #
      # @return [String] cleaned output
      #
      def clean_fastgpt_output(output)
        cleaned = output.dup
        # Remove reference markers like [1], [23], and full-width 【1】, possibly with surrounding spaces
        cleaned.gsub!(/\s*[\[\u3010]\d+[\]\u3011]\s*/, " ")
        # Compress runs of whitespace to a single space, but preserve newlines
        cleaned.gsub!(/[ \t]+/, " ")
        # Remove spaces directly before sentence punctuation
        cleaned.gsub!(/ +([.!?;:,])/, '\1')
        cleaned.strip
      end
    end

    SL::Searches.register "kagi", :search, self
  end
end
