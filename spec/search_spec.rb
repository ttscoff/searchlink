# frozen_string_literal: true

require 'spec_helper'

# https://github.com/thoiberg/cli-test
describe 'Search' do
  include CliTest

  it 'executes successfully' do
    execute_script('bin/searchlink', use_bundler: true, args: %w[-v])
    expect(last_execution).to be_successful
  end

  it 'returns correct result for TMDB' do
    execute_script('bin/searchlink', use_bundler: true, stdin_data: '[%](!tmdbt legends of tomorrow ++t)')
    expect(last_execution).to be_successful
    expected = %([DC's Legends of Tomorrow](https://www.themoviedb.org/tv/62643 "DC's Legends of Tomorrow"))
    expect(last_execution.stdout).to match(/#{Regexp.escape(expected)}/)
  end

  it 'returns correct result for DDG' do
    execute_script('bin/searchlink', use_bundler: true, stdin_data: '[brett terpstra](!g)')
    expect(last_execution).to be_successful
    expected = '[brett terpstra](https://brettterpstra.com/ "BrettTerpstra.com")'
    expect(last_execution.stdout).to match(/#{Regexp.escape(expected)}/)
  end

  it 'returns correct result iTunes' do
    execute_script('bin/searchlink', use_bundler: true, stdin_data: '[Inside Voices](!ialb)')
    expect(last_execution).to be_successful
    expected = '[Inside Voices](https://music.apple.com/us/album/inside-voices-ep/1566937199?uo=4&at=10l4tL&ct=searchlink "Inside Voices - EP by K.Flay")'
    expect(last_execution.stdout).to match(/#{Regexp.escape(expected)}/)
  end

  it 'returns correct results for a bunch of searches' do
    input =<<~EOINPUT
      * A search for specified text: [Marked](!g "Marked mac app").
      * A simple software search for [Fantastical](!s).
      * A simple google search [wikipedia neat neat neat](!g)
      * A Last.fm track search [neat neat neat](!lsong "The Damned Neat Neat Neat") (with specified search terms)
      * Mac app store search: [Marked on the MAS](!mas "Marked 2")
      * Mac App Store search [Marked direct](!masd "Marked") with direct dev site link.
      * iTunes app search: [Grindstone](!itu)
      * iTunes search, direct dev site link: [Grindstone direct](!itud "Grindstone")
      * This search: [](!mas "Omnifocus") will have its link text filled in with the title of the first result.
      * This is a wikipedia entry for [Sid Vicious](!wiki)
      * This will put the definition of [ambiguous](!def) in the title field of a link to the dictionary entry.
      * iTunes Artist search: [BRMC](!iart "Black Rebel Motorcycle Club")
      * Site specific search: [Keybindings](!brettterpstra.com "Keybinding Madness")
      * [ttscoff](!@t) and [ttscoff](!@f) and [ttscoff@nojack.ca](!@m)
      * A zero click result [%](!z disambiguation)
      * A YouTube search [marked 2 teleprompter](!yt)
      * [marked 2 teleprompter](!yte)
      * How to spell [balogne](!sp)
      * [%](!file brettterpstra header template filename:.afphoto)
      EOINPUT

    strings = [
      'https://apps.apple.com/us/app/marked-2-markdown-preview/id890031187?mt=12',
      'https://flexibits.com/fantastical',
      'https://en.wikipedia.org/wiki/Neat_Neat_Neat',
      'https://www.last.fm/music/The+Damned/_/Neat+Neat+Neat',
      'https://apps.apple.com/us/app/marked-2-markdown-preview/id890031187?mt=12&uo=4&at=10l4tL&ct=searchlink',
      'http://marked2app.com',
      'https://apps.apple.com/us/app/grindstone/id1357426636?uo=4&at=10l4tL&ct=searchlink',
      'http://www.capybaragames.com/',
      'https://apps.apple.com/us/app/omnifocus-3/id1346203938?mt=12&uo=4&at=10l4tL&ct=searchlink',
      'https://en.wikipedia.org/wiki/Sid_Vicious',
      'https://www.thefreedictionary.com/ambiguous',
      'https://music.apple.com/us/artist/black-rebel-motorcycle-club/624658?uo=4&at=10l4tL&ct=searchlink',
      'https://brettterpstra.com/2011/08/13/keybinding-madness/',
      'https://twitter.com/ttscoff',
      'https://www.facebook.com/ttscoff',
      'https://nojack.ca/@ttscoff',
      'https://en.wikipedia.org/wiki/Disambiguation_(disambiguation)',
      'https://www.youtube.com/watch?v=',
      'iframe width="560" height="315" src="https://www.youtube.com/embed/',
      'bologna',
      'BrettTerpstra.com%20Header%20Template/BrettTerpstra.com%20Header%20Template.afphoto'
    ]

    execute_script('bin/searchlink', use_bundler: true, stdin_data: input)
    expect(last_execution).to be_successful
    strings.each { |s| expect(last_execution.stdout).to match(/#{Regexp.escape(s)}/) }
    expect(last_execution.stdout).to match(/Processed: #{strings.count} links, 0 errors./)
  end
end
