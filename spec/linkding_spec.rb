# frozen_string_literal: true

require "spec_helper"

describe SL::LinkdingSearch do
  let(:link_text) { "my bookmark" }
  let(:server) { "https://links.example.com" }
  let(:api_key) { "secret-token" }

  before do
    allow(SL).to receive(:add_error)
    @original_config = SL.instance_variable_get(:@config)
    @config = @original_config.is_a?(Hash) ? @original_config.dup : {}
    SL.instance_variable_set(:@config, @config)
    @config["debug"] = true
    @config["custom_site_searches"] = {}
    @config["linkding_server"] = server
    @config["linkding_api_key"] = api_key
  end

  after do
    SL.instance_variable_set(:@config, @original_config)
  end

  def bookmark(url:, title:, description: "", notes: "", tags: [], date: "2024-01-01T00:00:00Z")
    {
      "url" => url,
      "title" => title,
      "description" => description,
      "notes" => notes,
      "tag_names" => tags,
      "date_added" => date
    }
  end

  def page(results, count: results.size)
    { "count" => count, "next" => nil, "results" => results }
  end

  def stub_pages(active, archived = page([]))
    allow(Curl::Json).to receive(:new).and_return(
      instance_double(Curl::Json, code: "200", json: active),
      instance_double(Curl::Json, code: "200", json: archived)
    )
  end

  it "registers !ld and !ding" do
    expect(SL::Searches.valid_search?("ld")).to be true
    expect(SL::Searches.valid_search?("ding")).to be true
  end

  it "asks for the server and API token in plugin config" do
    keys = described_class.settings[:config].map { |cfg| cfg[:key] }

    expect(keys).to eq(%w[linkding_server linkding_api_key])
  end

  it "returns false when the server is missing" do
    @config["linkding_server"] = ""
    allow(Curl::Json).to receive(:new)

    expect(described_class.search("ld", "searchlink", link_text)).to be false
    expect(SL).to have_received(:add_error).with("Missing Linkding server", anything)
    expect(Curl::Json).not_to have_received(:new)
  end

  it "returns false when the API token is missing" do
    @config["linkding_api_key"] = nil
    allow(Curl::Json).to receive(:new)

    expect(described_class.search("ld", "searchlink", link_text)).to be false
    expect(SL).to have_received(:add_error).with("Missing Linkding API token", anything)
    expect(Curl::Json).not_to have_received(:new)
  end

  it "prefers an exact title match and keeps the original link text" do
    stub_pages(page([
                      bookmark(url: "https://example.com/notes", title: "Some notes",
                               description: "searchlink pinboard", date: "2024-06-01T00:00:00Z"),
                      bookmark(url: "https://example.com/searchlink", title: "SearchLink Pinboard",
                               tags: ["pinboard"], date: "2020-01-01T00:00:00Z")
                    ]))

    url, title, text = described_class.search("ld", "searchlink pinboard", link_text)

    expect(url).to eq("https://example.com/searchlink")
    expect(title).to eq("SearchLink Pinboard")
    expect(text).to eq(link_text)
    expect(Curl::Json).to have_received(:new).with(
      "#{server}/api/bookmarks/?q=searchlink%20pinboard&limit=100&offset=0&sort=added_desc",
      headers: { "Authorization" => "Token #{api_key}" }
    )
  end

  it "picks the newer bookmark when scores tie" do
    stub_pages(page([
                      bookmark(url: "https://example.com/old", title: "SearchLink", date: "2020-01-01T00:00:00Z"),
                      bookmark(url: "https://example.com/new", title: "SearchLink", date: "2024-06-01T00:00:00Z")
                    ]))

    url, = described_class.search("ld", "searchlink", link_text)

    expect(url).to eq("https://example.com/new")
  end

  it "includes archived bookmarks" do
    stub_pages(
      page([]),
      page([bookmark(url: "https://example.com/old-post", title: "Archived SearchLink")])
    )

    url, title, = described_class.search("ld", "searchlink", link_text)

    expect(url).to eq("https://example.com/old-post")
    expect(title).to eq("Archived SearchLink")
    expect(Curl::Json).to have_received(:new).with(
      a_string_including("/api/bookmarks/archived/?q="),
      headers: { "Authorization" => "Token #{api_key}" }
    )
  end

  it "sends a leading quote as an exact phrase" do
    stub_pages(page([
                      bookmark(url: "https://example.com/partial", title: "History notes", description: "rome"),
                      bookmark(url: "https://example.com/phrase", title: "History of Rome")
                    ]))

    url, = described_class.search("ld", "'history of rome", link_text)

    expect(url).to eq("https://example.com/phrase")
    expect(Curl::Json).to have_received(:new).with(
      a_string_including("q=%22history%20of%20rome%22"),
      anything
    ).twice
  end

  it "strips a trailing slash and /api from the server URL" do
    @config["linkding_server"] = "https://links.example.com/api/"
    stub_pages(page([bookmark(url: "https://example.com/searchlink", title: "SearchLink")]))

    described_class.search("ld", "searchlink", link_text)

    expect(Curl::Json).to have_received(:new).with(
      a_string_starting_with("https://links.example.com/api/bookmarks/?"),
      anything
    )
  end

  it "returns false when Linkding rejects the token" do
    allow(Curl::Json).to receive(:new).and_return(
      instance_double(Curl::Json, code: "401", json: { "detail" => "Invalid token." })
    )

    expect(described_class.search("ld", "searchlink", link_text)).to be false
    expect(SL).to have_received(:add_error).with("Linkding request failed", "Invalid token.")
  end

  it "uses the URL when a bookmark has no title" do
    stub_pages(page([bookmark(url: "https://example.com/bare", title: "")]))

    _url, title, = described_class.search("ld", "example.com/bare", link_text)

    expect(title).to eq("https://example.com/bare")
  end
end
