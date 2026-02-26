# frozen_string_literal: true

require "spec_helper"

# https://github.com/thoiberg/cli-test
describe "CLI" do
  include CliTest

  describe "executes" do
    it "executes successfully" do
      execute_script("bin/searchlink", use_bundler: true, args: %w[-v])
      expect(last_execution).to be_successful
    end
  end

  describe SL::KagiSearch do
    let(:link_text) { "Brett Terpstra" }
    before do
      allow(SL).to receive(:notify)
      allow(SL).to receive(:add_error)
    end

    context "when performing a Kagi search (!k)" do
      it "falls back to DuckDuckGo when no API key is configured" do
        allow(described_class).to receive(:api_key?).and_return(false)
        allow(SL).to receive(:ddg).and_return(["https://example.com", "Example", link_text])

        url, title, text = described_class.search("k", "brett terpstra", link_text)

        expect(SL).to have_received(:ddg).with("brett terpstra", link_text, google: false)
        expect(url).to eq("https://example.com")
        expect(title).to eq("Example")
        expect(text).to eq(link_text)
      end

      it "returns first Kagi result when API key and response are valid" do
        described_class.instance_variable_set(:@api_key, "test_kagi_key")
        allow(described_class).to receive(:api_key?).and_return(true)

        kagi_response = {
          meta: { id: "id", api_balance: 9.0 },
          data: [
            {
              url: "https://brettterpstra.com/",
              title: "Brett Terpstra",
              snippet: "Brett Terpstra is a writer and developer..."
            }
          ]
        }
        json_double = instance_double(Curl::Json, code: "200", json: kagi_response)
        allow(Curl::Json).to receive(:new).and_return(json_double)

        url, title, text = described_class.search("k", "brett terpstra", link_text)

        expect(url).to eq("https://brettterpstra.com/")
        expect(title).to eq("Brett Terpstra")
        expect(text).to eq(link_text)
      end
    end

    context "when performing a FastGPT query (!gpt)" do
      it "returns an embed with output and references when API key and response are valid" do
        described_class.instance_variable_set(:@api_key, "test_kagi_key")
        allow(described_class).to receive(:api_key?).and_return(true)

        fastgpt_response = {
          meta: { id: "id", api_balance: 9.0 },
          data: {
            output: "Brett Terpstra[1] is a writer 【2】 and developer .",
            references: [
              { title: "BrettTerpstra.com", snippet: "...", url: "https://brettterpstra.com/" }
            ]
          }
        }
        json_double = instance_double(Curl::Json, code: "200", json: fastgpt_response)
        allow(Curl::Json).to receive(:new).and_return(json_double)

        kind, body, text = described_class.search("gpt", "Who is Brett Terpstra", link_text)

        expect(kind).to eq("embed")
        expect(body).to include("Brett Terpstra is a writer and developer.")
        expect(body).not_to match(/[\[\u3010]\d+[\]\u3011]/)
        expect(body).not_to include("developer .")
        expect(body).to include("https://brettterpstra.com/")
        expect(text).to eq(link_text)
      end

      it "returns a fallback embed when Kagi is not configured" do
        allow(described_class).to receive(:api_key?).and_return(false)

        kind, body, text = described_class.search("gpt", "Who is Brett Terpstra", link_text)

        expect(kind).to eq("embed")
        expect(body).to include("Kagi FastGPT is not configured")
        expect(text).to eq(link_text)
      end
    end
  end

  # Array of searches and results
  # [[search, expected result],...]
  searches = [
    # default
    ["* A default search [brett terpstra]()", "https://brettterpstra.com"],
    ["* An empty link that needs a title [](https://rspec.rubystyle.guide/)", "[RSpec Style Guide](https://rspec.rubystyle.guide/"],
    # social links
    ["* [%](!@f ttscoff)", "https://www.facebook.com/ttscoff"],
    ["* [%](!@i ttscoff)", "https://www.instagram.com/ttscoff/"],
    ["* [%](!@l ttscoff)", "https://www.linkedin.com/in/ttscoff/"],
    ["* [%](!@m ttscoff@nojack.ca)", "https://nojack.ca/@ttscoff"],
    ["* [%](!@t ttscoff)", "https://twitter.com/ttscoff"],
    # amazon
    ["* An Amazon search [owc express 4m2](!a)", %r{https://www\.amazon\.com/dp/[A-Z0-9&=]+/\?ref=as_li_ss_tl&ie=UTF8&linkCode=sl1&tag=}i],
    # apple music
    ["* A general Apple Music search [%](!am k.flay imagine dragons)", "https://music.apple.com/us/album/thunder-official-remix/1445014880"],
    ["* An Apple Music podcast search [Overtired](!ampod)", "https://podcasts.apple.com/us/podcast/overtired/id944540924?uo=4&app=music&at=10l4tL&ct=searchlink"],
    ["* An Apple Music artist search [%](!amart taylor swift)", "https://music.apple.com/us/artist/taylor-swift"],
    ["* An Apple Music album search [%](!amalb k.flay inside voices outside voices)", "https://music.apple.com/us/album/inside-voices-outside-voices"],
    ["* An Apple Music song search [%](!amsong k.flay the muck)", "https://music.apple.com/us/album/the-muck/1606694205"],
    # bitly
    ["* A [shortened link](!bl https://brettterpstra.com)", "https://bit.ly/3uEzRKE"],
    # TinyURL modifier
    ["* A tinyurl shortened link from modifier [%](!g_t https://brettterpstra.com)", "https://tinyurl"],
    # DuckDuckGo/Google
    ["* A DuckDuckGo search [brett terpstra](!ddg +the lab ++t)",
     '[brett terpstra](https://brettterpstra.com/ "BrettTerpstra.com")'],
    ["* A search for specified text: [Marked](!g Marked 2 mac app store).", "https://apps.apple.com/us/app/marked-2-markdown-preview/id890031187?mt=12"],
    ["* A simple google search [](!g wikipedia <neat neat neat>)", "https://en.wikipedia.org/wiki/Neat_Neat_Neat"],
    # definition
    ["* This will put the definition of [ambiguous](!def) in the title field of a link to the dictionary entry.", "https://www.wordnik.com/words/ambiguous"],
    # spotlight
    ["* [%](!file filename:brettterpstra.com header template filename:.afphoto)", /BrettTerpstra\.com.*?\.afphoto/],
    # GitHub
    ["* A GitHub search with user and repo [%](!gh ttscoff searchlink)", "https://github.com/ttscoff/searchlink"],
    ["* A GitHub search with specifiers [%](!gh u:ttscoff searchlink)", "https://github.com/ttscoff/searchlink"],
    ["* A Gist search with search term [%](!gist ttscoff searchlink.rb)", %r{https://gist.github.com/(ttscoff/)?3900158}],
    ["* A gist embed with user/id [%](!giste ttscoff/9064738)", "https://gist.github.com/ttscoff/9064738.js"],
    ["* A gist embed with just id [%](!giste 9064738)", "https://gist.github.com/ttscoff/9064738.js"],
    # iTunes
    ["* iTunes album search [Inside Voices / Outside Voices](!ialb + k.flay)", "[Inside Voices / Outside Voices](https://music.apple.com/us/album"],
    ['* iTunes Artist search: [BRMC](!iart "Black Rebel Motorcycle Club")', "https://music.apple.com/us/artist/black-rebel-motorcycle-club/624658?uo=4&at=10l4tL&ct=searchlink"],
    ["* An iTunes podcast search [Overtired](!ipod)", "https://podcasts.apple.com/us/podcast/overtired/id944540924?uo=4&at=10l4tL&ct=searchlink"],
    # Last.fm
    ["* A Last.fm artist search [The Damned](!lart)", "https://www.last.fm/music/The+Damned"],
    ['* A Last.fm track search [neat neat neat](!lsong "The Damned Neat Neat Neat") (with specified search terms)', "https://www.last.fm/music/The+Damned/_/Neat+Neat+Neat"],
    # Mac App Store
    ['* Mac app store search: [Marked on the MAS](!mas "Marked 2")', "https://apps.apple.com/us/app/marked-2-markdown-preview/id890031187?mt=12&uo=4&at=10l4tL&ct=searchlink"],
    ['* This search: [](!mas "Omnifocus 4" accomplish more) will have its link text filled in', "[Omnifocus 4](https://apps.apple.com/us/app/omnifocus-4"],
    ['* Mac App Store search [Marked direct](!masd "Marked") with direct dev site link.', "http://marked2app.com"],
    # iTunes App Store
    ["* iTunes app search: [Grindstone](!itu)", "https://apps.apple.com/us/app/grindstone/id1357426636?uo=4&at=10l4tL&ct=searchlink"],
    ['* iTunes search, direct dev site link: [Grindstone direct](!itud "Grindstone")', "http://www.capybaragames.com/"],
    # Pinboard
    # Pinboard API is down for now 2025-03-30
    # ["* A Pinboard search for [OWC Express 4M2](!pb)", "https://amzn.to/3Vri9qx"],
    # Software
    ["* A simple software search for [Fantastical](!s).", "https://flexibits.com/fantastical"],
    # StackOverflow
    ["StackOverflow accepted answer [%](!soa longest string in array ruby)", /22438646.*?#answer-22438653/],
    # Spelling
    ["* How to spell [balogne](!sp)", "bologna"],
    # Twitter embed
    ["[https://twitter.com/hynek/status/1613776397394214913](!te)", "https://twitter.com/hynek/status/1613776397394214913?ref_src=twsrc%5Etfw"],
    # TMDB
    ["* A TMDB multi search [%](!tmdb brad pitt actor)", "[Brad Pitt](https://www.imdb.com/name/nm0000093"],
    ["* A TMDB TV search [%](!tmdbt legends of tomorrow)", "[DC's Legends of Tomorrow](https://www.themoviedb.org/tv/62643"],
    ["* A TMDB movie search [%](!tmdbm 12 monkeys)", "[Twelve Monkeys](https://www.themoviedb.org/movie/63"],
    # wikipedia
    ["* This is a wikipedia entry for [Sid Vicious](!wiki)", "https://en.wikipedia.org/wiki/Sid_Vicious"],
    # youtube
    ["* A YouTube search [marked 2 teleprompter](!yt)", %r{https://www\.youtube\.com/watch\?v=[a-z0-9\-_]+}i],
    ["A YouTube embed [marked 2 teleprompter](!yte)", %r{iframe width="\d+" height="\d+" src="https://www\.youtube\.com/embed/[a-z0-9\-_]+"}i],
    # zero click
    ["* A zero click result [%](!z disambiguation)", "https://en.wikipedia.org/wiki/Disambiguation_(disambiguation)"],
    # Site specific
    ["* Site specific search: [Keybindings](!brettterpstra.com <Keybinding madness part 2>)",
     "https://brettterpstra.com/2011/11/10/the-keys-that-bind-keybinding-madness-part-2/"],
    # DuckDuckGo
    ["* DuckDuckGo search: [%](!ddg brett terpstra Keybinding madness part 2)",
     "the-keys-that-bind-keybinding-madness-part-2/"],
    # Kagi (falls back to DDG if not configured)
    ["* A Kagi search [brett terpstra](!k)", "brettterpstra.com"],
  ]

  searches.each.with_index do |search, i|
    describe "executes search" do
      context "(#{i + 1}/#{searches.count}) when given the text '#{search[0]}'" do
        it "returns #{search[1]}" do
          ENV["SL_NO_CONFIRM"] = "true"
          execute_script("bin/searchlink", use_bundler: true, stdin_data: search[0])
          expect(last_execution).to be_successful

          result = search[1].is_a?(Regexp) ? search[1] : /#{Regexp.escape(search[1])}/
          expect(last_execution.stdout).to match(result)
        end
      end
    end
  end
end
