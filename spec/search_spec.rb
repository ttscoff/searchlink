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
    ['[brett terpstra]()', 'https://brettterpstra.com'],
    ['[brett terpstra](!g ++t)', '[brett terpstra](https://brettterpstra.com/ "BrettTerpstra.com")'],
    ['A general Apple Music search [%](!am k.flay imagine dragons)', 'https://music.apple.com/us/album/thunder-official-remix/1445014880'],
    ['* An Apple Music podcast search [Overtired](!ampod)', 'https://podcasts.apple.com/us/podcast/overtired/id944540924?uo=4&app=music&at=10l4tL&ct=searchlink'],
    ['An Apple Music artist search [%](!amart taylor swift)', 'https://music.apple.com/us/artist/taylor-swift'],
    ['An Apple Music album search [%](!amalb k.flay inside voices outside voices)', 'https://music.apple.com/us/album/inside-voices-outside-voices'],
    ['An Apple Music song search [%](!amsong k.flay the muck)', 'https://music.apple.com/us/album/the-muck/1604651969'],
    ['* An iTunes podcast search [Overtired](!ipod)', 'https://podcasts.apple.com/us/podcast/overtired/id944540924?uo=4&at=10l4tL&ct=searchlink'],
    ['An iTunes artist search [%](!iart k.flay)', 'https://music.apple.com/us/artist/k-flay/297760267'],
    ['iTunes album search [Inside Voices / Outside Voices](!ialb + k.flay)', '[Inside Voices / Outside Voices](https://music.apple.com/us/album'],
    ['An iTunes song search [%](!amsong k.flay the muck)', 'https://music.apple.com/us/album/the-muck/1604651969'],
    ['* iTunes app search: [Grindstone](!itu)', 'https://apps.apple.com/us/app/grindstone/id1357426636?uo=4&at=10l4tL&ct=searchlink'],
    ['* iTunes search, direct dev site link: [Grindstone direct](!itud "Grindstone")', 'http://www.capybaragames.com/'],
    ['* Mac app store search: [Marked on the MAS](!mas "Marked 2")', 'https://apps.apple.com/us/app/marked-2-markdown-preview/id890031187?mt=12&uo=4&at=10l4tL&ct=searchlink'],
    ['* Mac App Store search [Marked direct](!masd "Marked") with direct dev site link.', 'http://marked2app.com'],
    ['* An Amazon search [owc express 4m2](!a)', %r{https://www\.amazon\.com/dp/[A-Z0-9]+/\?ref=as_li_ss_tl&ie=UTF8&linkCode=sl1&tag=}],
    ['[%](!tmdbt legends of tomorrow)', "[DC's Legends of Tomorrow](https://www.themoviedb.org/tv/62643"],
    ['* A search for specified text: [Marked](!g "Marked mac app").', 'https://apps.apple.com/us/app/marked-2-markdown-preview/id890031187?mt=12'],
    ['* A simple software search for [Fantastical](!s).', 'https://flexibits.com/fantastical'],
    ['* A simple google search [wikipedia neat neat neat](!g)', 'https://en.wikipedia.org/wiki/Neat_Neat_Neat'],
    ['* A [shortened link](!bl https://brettterpstra.com)', 'https://bit.ly/3uEzRKE'],
    ['* A Last.fm artist search [The Damned](!lart)', 'https://www.last.fm/music/The+Damned'],
    ['* A Last.fm track search [neat neat neat](!lsong "The Damned Neat Neat Neat") (with specified search terms)', 'https://www.last.fm/music/The+Damned/_/Neat+Neat+Neat'],
    ['* This search: [](!mas "Omnifocus") will have its link text filled in with the title of the first result.', 'https://apps.apple.com/us/app/omnifocus-3/id1346203938?mt=12&uo=4&at=10l4tL&ct=searchlink'],
    ['* This is a wikipedia entry for [Sid Vicious](!wiki)', 'https://en.wikipedia.org/wiki/Sid_Vicious'],
    ['* This will put the definition of [ambiguous](!def) in the title field of a link to the dictionary entry.', 'https://www.wordnik.com/words/ambiguous'],
    ['* iTunes Artist search: [BRMC](!iart "Black Rebel Motorcycle Club")', 'https://music.apple.com/us/artist/black-rebel-motorcycle-club/624658?uo=4&at=10l4tL&ct=searchlink'],
    ['* Site specific search: [Keybindings](!brettterpstra.com "Keybinding Madness")', 'https://brettterpstra.com/2011/08/13/keybinding-madness/'],
    ['* [%](!@t ttscoff)', 'https://twitter.com/ttscoff'],
    ['* [%](!@f ttscoff)', 'https://www.facebook.com/ttscoff'],
    ['* [%](!@m ttscoff@nojack.ca)', 'https://nojack.ca/@ttscoff'],
    ['* A zero click result [%](!z disambiguation)', 'https://en.wikipedia.org/wiki/Disambiguation_(disambiguation)'],
    ['* A YouTube search [marked 2 teleprompter](!yt)', %r{https://www\.youtube\.com/watch\?v=[a-z0-9\-_]+}i],
    ['* How to spell [balogne](!sp)', 'bologna'],
    ['* [%](!file brettterpstra header template filename:.afphoto)', 'BrettTerpstra.com%20Header%20Template.afphoto'],
    ['* A Firefox history search [GitHub Brett Terpstra](!hfh)', 'https://github.com/ttscoff'],
    ['* A Pinboard search for [OWC Express 4M2](!pb)', 'https://amzn.to/3Vri9qx'],
    ['A YouTube embed [marked 2 teleprompter](!yte)', %r{iframe width="\d+" height="\d+" src="https://www\.youtube\.com/embed/[a-z0-9\-_]+"}i],
    ['[https://twitter.com/hynek/status/1613776397394214913](!te)', 'https://twitter.com/hynek/status/1613776397394214913?ref_src=twsrc%5Etfw']
  ]

  searches.each do |search|
    describe "executes search for #{search[0]}" do
      it "and returns #{search[1]}" do
        execute_script('bin/searchlink', use_bundler: true, stdin_data: search[0])
        expect(last_execution).to be_successful

        result = search[1].is_a?(Regexp) ? search[1] : /#{Regexp.escape(search[1])}/
        expect(last_execution.stdout).to match(result)
      end
    end
  end
end
