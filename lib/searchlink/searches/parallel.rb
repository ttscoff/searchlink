# frozen_string_literal: true

module SL
  # Find a source URL through Parallel's anonymous Search MCP.
  class ParallelSearch
    ENDPOINT = URI("https://mcp.parallel.ai/mcp")
    PROTOCOL_VERSION = "2025-03-26"
    USER_AGENT = "SearchLink/#{SL::VERSION}".freeze
    NETWORK_ERRORS = [IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError, Net::ProtocolError, Net::OpenTimeout, Net::ReadTimeout].freeze

    class RequestError < StandardError; end

    class << self
      def settings
        { trigger: "parallel", searches: [["parallel", "Parallel Web Search"]] }
      end

      def search(_search_type, search_terms, link_text)
        query = search_terms.gsub("%22", '"')
        results = search_results(query)
        results.each do |result|
          next unless result.is_a?(Hash) && source_url?(result["url"])

          url = result.fetch("url")
          title = safe_title(result["title"], url)
          title.remove_seo!(url) if SL.config["remove_seo"]
          return [url, title, link_text]
        end

        [false, "No Parallel search results", link_text]
      rescue RequestError, JSON::ParserError, *NETWORK_ERRORS
        SL.add_error("Parallel error", "Could not get results from Parallel Web Search")
        [false, "Parallel search failed", link_text]
      end

      private

      def search_results(query)
        timeout = SL.config["timeout"]
        options = { use_ssl: ENDPOINT.scheme == "https", open_timeout: timeout, read_timeout: timeout }
        Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, **options) do |http|
          headers = {
            "Accept" => "application/json, text/event-stream",
            "Content-Type" => "application/json",
            "User-Agent" => USER_AGENT
          }
          session = post(http, headers, "initialize", 1, {
            protocolVersion: PROTOCOL_VERSION,
            capabilities: {},
            clientInfo: { name: "SearchLink", version: SL::VERSION }
          })
          raise RequestError unless rpc_result(session, 1)["protocolVersion"] == PROTOCOL_VERSION

          headers["MCP-Protocol-Version"] = PROTOCOL_VERSION
          headers["Mcp-Session-Id"] = session["Mcp-Session-Id"] if session["Mcp-Session-Id"]
          post(http, headers, "notifications/initialized")
          response = post(http, headers, "tools/call", 2, {
            name: "web_search",
            arguments: { objective: query, search_queries: [query] }
          })
          extract_results(rpc_result(response, 2))
        ensure
          close_session(http, headers) if headers["Mcp-Session-Id"]
        end
      end

      def close_session(http, headers)
        # Session cleanup is best effort, including servers that disallow DELETE.
        http.open_timeout = http.read_timeout = 1
        http.delete(ENDPOINT.request_uri, headers)
      rescue *NETWORK_ERRORS
        nil
      end

      def post(http, headers, method, id = nil, params = nil)
        message = { jsonrpc: "2.0", method: method }
        message[:id] = id if id
        message[:params] = params if params
        response = http.post(ENDPOINT.request_uri, JSON.generate(message), headers)
        raise RequestError unless response.is_a?(Net::HTTPSuccess)

        response
      end

      def rpc_result(response, id)
        messages = if response.content_type == "text/event-stream"
                     response.body.to_s.split(/\r?\n\r?\n/).map do |event|
                       event.lines.grep(/\Adata:/).map { |line| line.sub(/\Adata: ?/, "") }.join
                     end
                   else
                     [response.body.to_s]
                   end
        messages.each do |message|
          next if message.empty?

          envelope = JSON.parse(message)
          next unless envelope.is_a?(Hash) && envelope["jsonrpc"] == "2.0" && envelope["id"] == id

          result = envelope["result"]
          return result if result.is_a?(Hash) && !envelope.key?("error")

          break
        end
        raise RequestError
      end

      def extract_results(result)
        raise RequestError if result["isError"]

        payload = result["structuredContent"]
        unless payload
          content = result["content"]
          block = content.find { |item| item.is_a?(Hash) && item["type"] == "text" } if content.is_a?(Array)
          raise RequestError unless block && block["text"].is_a?(String)

          payload = JSON.parse(block["text"])
        end

        raise RequestError unless payload.is_a?(Hash) && payload["results"].is_a?(Array)

        payload.fetch("results")
      end

      def source_url?(url)
        return false unless url.is_a?(String)

        uri = URI.parse(url)
        return false unless uri.is_a?(URI::HTTP) && uri.host && !uri.host.empty? && !uri.userinfo

        # SearchLink inserts the URL verbatim in a Markdown link destination.
        depth = 0
        url.scan(/[()]/).each do |paren|
          depth += paren == "(" ? 1 : -1
          return false if depth.negative?
        end
        depth.zero?
      rescue URI::InvalidURIError
        false
      end

      def safe_title(title, url)
        text = title.is_a?(String) ? title.gsub(/[[:cntrl:]\p{Zl}\p{Zp}]/, " ").strip : ""
        text = url if text.empty?

        # A page title can become the label of an otherwise empty Markdown link.
        text.gsub(/[&<>"'\[\]\\`*_~]/) { |character| "&##{character.ord};" }
      end
    end

    Searches.register "parallel", :search, self
  end
end
