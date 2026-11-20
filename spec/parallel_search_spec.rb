# frozen_string_literal: true

require "spec_helper"

describe SL::ParallelSearch do
  let(:http) { instance_double(Net::HTTP) }
  let(:query) { "Ruby's %22Net::HTTP%22 docs" }
  let(:label) { "Ruby docs" }
  let(:url) { "https://docs.ruby-lang.org/en/3.3/Net/HTTP.html?foo=1&bar=2#method-i-get" }

  before do
    allow(SL).to receive(:config).and_return("timeout" => 15)
    allow(SL).to receive(:add_error)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:delete)
  end

  def response(result, id, streaming: false)
    body = JSON.generate(jsonrpc: "2.0", id: id, result: result)
    packet = Net::HTTPOK.new("1.1", "200", "OK")
    packet["Content-Type"] = streaming ? "text/event-stream" : "application/json"
    allow(packet).to receive(:body).and_return(streaming ? ": ping\r\n\r\nevent: message\r\ndata: #{body}\r\n\r\n" : body)
    packet
  end

  def stub_responses(search_response)
    initialize_response = response({ protocolVersion: "2025-03-26" }, 1)
    initialize_response["Mcp-Session-Id"] = "fixture-session"
    initialized = Net::HTTPAccepted.new("1.1", "202", "Accepted")
    allow(http).to receive(:post).and_return(initialize_response, initialized, search_response)
  end

  it "uses the original source URL and treats the streamed title as Markdown text" do
    result = { results: [
      { url: "javascript:bad" },
      { url: "https://example.com/)" },
      { url: url, title: "Ruby [docs]\n<script>" }
    ] }
    tool_result = { content: [{ type: "text", text: JSON.generate(result) }] }
    stub_responses(response(tool_result, 2, streaming: true))

    expect(described_class.search("parallel", query, label)).to eq([url, "Ruby &#91;docs&#93; &#60;script&#62;", label])
    expect(http).to have_received(:post).with(
      "/mcp",
      JSON.generate(jsonrpc: "2.0", method: "tools/call", id: 2, params: {
        name: "web_search", arguments: { objective: 'Ruby\'s "Net::HTTP" docs', search_queries: ['Ruby\'s "Net::HTTP" docs'] }
      }),
      hash_including("Mcp-Session-Id" => "fixture-session", "User-Agent" => "SearchLink/#{SL::VERSION}")
    )
    expect(http).to have_received(:delete).with("/mcp", hash_including("Mcp-Session-Id" => "fixture-session"))
  end

  it "accepts a JSON result with no links" do
    stub_responses(response({ structuredContent: { results: [] } }, 2))

    expect(described_class.search("parallel", query, label)).to eq([false, "No Parallel search results", label])
  end

  it "reports an MCP tool error without sending the query to another provider" do
    stub_responses(response({ isError: true, content: [{ type: "text", text: "Service unavailable" }] }, 2))
    expect(SL).not_to receive(:ddg)

    expect(described_class.search("parallel", query, label)).to eq([false, "Parallel search failed", label])
  end
end
