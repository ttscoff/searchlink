# frozen_string_literal: true

require 'spec_helper'

# https://github.com/thoiberg/cli-test
describe 'CLI' do
  include CliTest

  describe 'executes' do
    it 'executes successfully' do
      execute_script('bin/searchlink', use_bundler: true, args: %w[-v])
      expect(last_execution).to be_successful
    end
  end

  # Array of searches and results
  # [[search, expected result],...]
  searches = [
    # default
    ['* A default search [brett terpstra]()', 'https://brettterpstra.com'],
    ['* An empty link that needs a title [](https://rspec.rubystyle.guide/)', '[RSpec Style Guide](https://rspec.rubystyle.guide/'],
    # social links
    ['* [%](!@f ttscoff)', 'https://www.facebook.com/ttscoff'],
    ['* [%](!@i ttscoff)', 'https://www.instagram.com/ttscoff/'],
    ['* [%](!@l ttscoff)', 'https://www.linkedin.com/in/ttscoff/'],
    ['* [%](!@m ttscoff@nojack.ca)', 'https://nojack.ca/@ttscoff'],
    ['* [%](!@t ttscoff)', 'https://twitter.com/ttscoff'],
    # amazon
    ['* An Amazon search [owc express 4m2](!a)', %r{https://www\.amazon\.com/dp/[A-Z0-9&=]+/\?ref=as_li_ss_tl&ie=UTF8&linkCode=sl1&tag=}i],
    # apple music
    ['* A general Apple Music search [%](!am k.flay imagine dragons)', 'https://music.apple.com/us/album/thunder-official-remix/1445014880'],
    ['* An Apple Music podcast search [Overtired](!ampod)', 'https://podcasts.apple.com/us/podcast/overtired/id944540924?uo=4&app=music&at=10l4tL&ct=searchlink'],
    ['* An Apple Music artist search [%](!amart taylor swift)', 'https://music.apple.com/us/artist/taylor-swift'],
    ['* An Apple Music album search [%](!amalb k.flay inside voices outside voices)', 'https://music.apple.com/us/album/inside-voices-outside-voices'],
    ['* An Apple Music song search [%](!amsong k.flay the muck)', 'https://music.apple.com/us/album/the-muck/1606694205'],
    # bitly
    ['* A [shortened link](!bl https://brettterpstra.com)', 'https://bit.ly/3uEzRKE'],
    # DuckDuckGo/Google
    ['* A DuckDuckGo search [brett terpstra](!ddg ++t)', '[brett terpstra](https://brettterpstra.com/ "BrettTerpstra.com")'],
    ['* A search for specified text: [Marked](!g Marked 2 mac app store).', 'https://apps.apple.com/us/app/marked-2-markdown-preview/id890031187?mt=12'],
    ['* A simple google search [wikipedia <neat neat neat>](!g)', 'https://en.wikipedia.org/wiki/Neat_Neat_Neat'],
    # definition
    ['* This will put the definition of [ambiguous](!def) in the title field of a link to the dictionary entry.', 'https://www.wordnik.com/words/ambiguous'],
    # spotlight
    ['* [%](!file brettterpstra header template filename:.afphoto)', 'BrettTerpstra.com%20Header%20Template.afphoto'],
    # GitHub
    ['* A GitHub search with user and repo [%](!gh ttscoff searchlink)', 'https://github.com/ttscoff/searchlink'],
    ['* A GitHub search with specifiers [%](!gh u:ttscoff searchlink)', 'https://github.com/ttscoff/searchlink'],
    ['* A Gist search with search term [%](!gist ttscoff searchlink.rb)', %r{https://gist.github.com/(ttscoff/)?3900158}],
    ['* A gist embed with user/id [%](!giste ttscoff/9064738)', 'https://gist.github.com/ttscoff/9064738.js'],
    ['* A gist embed with just id [%](!giste 9064738)', 'https://gist.github.com/ttscoff/9064738.js'],
    # history
    ['* A general history and bookmark search [%](!h brett terpstra forum searchlink)', 'BrettTerpstra.com Forum'],
    ['* An Arc history search [%](!hah brett terpstra)', 'https://brettterpstra.com/'],
    ['* An Arc bookmark search [%](!hab backbeat podman)', 'https://podman.backbeatmedia.com'],
    ['* A Brave history search [%](!hbh 2022 hardware)', 'https://brettterpstra.com/2022/12/31/bretts-favorites-2022-hardware'],
    ['* A Brave bookmark search [%](!hbb backbeat podman)', 'https://podman.backbeatmedia.com'],
    ['* A Chrome bookmark search [%](!hcb 2022 hardware)', 'https://brettterpstra.com/2022/12/31/bretts-favorites-2022-hardware'],
    ['* A Chrome history search [%](!hch boss begleri)', 'https://www.aroundsquare.com/collections/begleri/products/micro-boss-begleri-exotics'],
    ['* An Edge bookmark search [%](!heb 2022 hardware)', 'https://brettterpstra.com/2022/12/31/bretts-favorites-2022-hardware'],
    ['* An Edge history search [%](!heh brett terpstra)', 'https://brettterpstra.com/'],
    ['* A Firefox bookmark search [%](!hfb 2022 hardware)', 'https://brettterpstra.com/2022/12/31/bretts-favorites-2022-hardware'],
    ['* A Firefox history search [markdown exports mindmeister](!hfh)', 'https://gist.github.com/ttscoff/cd2a6c17964cccfb6665'],
    ['* A Safari bookmark search [%](!hsb visionmedia mocha)', 'https://github.com/visionmedia/mocha'],
    ['* A Safari history search [%](!hsh oracle template repo)', 'oracle/template-repo'],
    # iTunes
    ['* iTunes album search [Inside Voices / Outside Voices](!ialb + k.flay)', '[Inside Voices / Outside Voices](https://music.apple.com/us/album'],
    ['* iTunes Artist search: [BRMC](!iart "Black Rebel Motorcycle Club")', 'https://music.apple.com/us/artist/black-rebel-motorcycle-club/624658?uo=4&at=10l4tL&ct=searchlink'],
    ['* An iTunes podcast search [Overtired](!ipod)', 'https://podcasts.apple.com/us/podcast/overtired/id944540924?uo=4&at=10l4tL&ct=searchlink'],
    # Last.fm
    ['* A Last.fm artist search [The Damned](!lart)', 'https://www.last.fm/music/The+Damned'],
    ['* A Last.fm track search [neat neat neat](!lsong "The Damned Neat Neat Neat") (with specified search terms)', 'https://www.last.fm/music/The+Damned/_/Neat+Neat+Neat'],
    # Mac App Store
    ['* Mac app store search: [Marked on the MAS](!mas "Marked 2")', 'https://apps.apple.com/us/app/marked-2-markdown-preview/id890031187?mt=12&uo=4&at=10l4tL&ct=searchlink'],
    ['* This search: [](!mas "Omnifocus 3" accomplish more) will have its link text filled in', '[Omnifocus 3](https://apps.apple.com/us/app/omnifocus-3'],
    ['* Mac App Store search [Marked direct](!masd "Marked") with direct dev site link.', 'http://marked2app.com'],
    # iTunes App Store
    ['* iTunes app search: [Grindstone](!itu)', 'https://apps.apple.com/us/app/grindstone/id1357426636?uo=4&at=10l4tL&ct=searchlink'],
    ['* iTunes search, direct dev site link: [Grindstone direct](!itud "Grindstone")', 'http://www.capybaragames.com/'],
    # Pinboard
    ['* A Pinboard search for [OWC Express 4M2](!pb)', 'https://amzn.to/3Vri9qx'],
    # Software
    ['* A simple software search for [Fantastical](!s).', 'https://flexibits.com/fantastical'],
    # StackOverflow
    ['StackOverflow accepted answer [%](!soa longest string in array ruby)', /22438646.*?#answer-22438653/],
    # Spelling
    ['* How to spell [balogne](!sp)', 'bologna'],
    # Twitter embed
    ['[https://twitter.com/hynek/status/1613776397394214913](!te)', 'https://twitter.com/hynek/status/1613776397394214913?ref_src=twsrc%5Etfw'],
    # TMDB
    ['* A TMDB multi search [%](!tmdb brad pitt actor)', '[Brad Pitt](https://www.imdb.com/name/nm0000093'],
    ['* A TMDB TV search [%](!tmdbt legends of tomorrow)', "[DC's Legends of Tomorrow](https://www.themoviedb.org/tv/62643"],
    ['* A TMDB movie search [%](!tmdbm 12 monkeys)', '[Twelve Monkeys](https://www.themoviedb.org/movie/63'],
    # wikipedia
    ['* This is a wikipedia entry for [Sid Vicious](!wiki)', 'https://en.wikipedia.org/wiki/Sid_Vicious'],
    # youtube
    ['* A YouTube search [marked 2 teleprompter](!yt)', %r{https://www\.youtube\.com/watch\?v=[a-z0-9\-_]+}i],
    ['A YouTube embed [marked 2 teleprompter](!yte)', %r{iframe width="\d+" height="\d+" src="https://www\.youtube\.com/embed/[a-z0-9\-_]+"}i],
    # zero click
    ['* A zero click result [%](!z disambiguation)', 'https://en.wikipedia.org/wiki/Disambiguation_(disambiguation)'],
    # Site specific
    ['* Site specific search: [Keybindings](!brettterpstra.com <Keybinding madness part 2>)', 'https://brettterpstra.com/2011/08/13/keybinding-madness/'],
    # DuckDuckGo
    ['* DuckDuckGo search: [%](!ddg brett terpstra Keybinding madness part 2)', 'the-keys-that-bind-keybinding-madness-part-2/']
  ]

  searches.each.with_index do |search, i|
    describe 'executes search' do
      context "(#{i + 1}/#{searches.count}) when given the text '#{search[0]}'" do
        it "returns #{search[1]}" do
          execute_script('bin/searchlink', use_bundler: true, stdin_data: search[0])
          expect(last_execution).to be_successful

          result = search[1].is_a?(Regexp) ? search[1] : /#{Regexp.escape(search[1])}/
          expect(last_execution.stdout).to match(result)
        end
      end
    end
  end
end
