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

  describe 'searches TMDB' do
    it 'returns correct result for TMDB' do
      execute_script('bin/searchlink', use_bundler: true, stdin_data: '[%](!tmdbt legends of tomorrow ++t)')
      expect(last_execution).to be_successful
      expected = %([DC's Legends of Tomorrow](https://www.themoviedb.org/tv/62643 "DC's Legends of Tomorrow"))
      expect(last_execution.stdout).to match(/#{Regexp.escape(expected)}/)
    end
  end

  describe 'searches DDG' do
    it 'returns correct result for DDG' do
      execute_script('bin/searchlink', use_bundler: true, stdin_data: '[brett terpstra](!g)')
      expect(last_execution).to be_successful
      expected = '[brett terpstra](https://brettterpstra.com/ "BrettTerpstra.com")'
      expect(last_execution.stdout).to match(/#{Regexp.escape(expected)}/)
    end
  end

  describe 'searches iTunes' do
    it 'returns correct result iTunes' do
      execute_script('bin/searchlink', use_bundler: true, stdin_data: '[Inside Voices / Outside Voices](!ialb + k.flay)')
      expect(last_execution).to be_successful
      expected = '[Inside Voices / Outside Voices](https://music.apple.com/us/album/inside-voices-outside-voices/1604651969?uo=4&at=10l4tL&ct=searchlink "Inside Voices / Outside Voices by K.Flay")'
      expect(last_execution.stdout).to match(/#{Regexp.escape(expected)}/)
    end
  end


  searches = [
    '* A search for specified text: [Marked](!g "Marked mac app").',
    '* A simple software search for [Fantastical](!s).',
    '* A simple google search [wikipedia neat neat neat](!g)',
    '* An Apple Music podcast search [Overtired](!ampod)',
    '* An iTunes podcast search [Overtired](!ipod)',
    '* A [shortened link](!bl https://brettterpstra.com)',
    '* A Last.fm artist search [The Damned](!lart)',
    '* A Last.fm track search [neat neat neat](!lsong "The Damned Neat Neat Neat") (with specified search terms)',
    '* Mac app store search: [Marked on the MAS](!mas "Marked 2")',
    '* Mac App Store search [Marked direct](!masd "Marked") with direct dev site link.',
    '* iTunes app search: [Grindstone](!itu)',
    '* iTunes search, direct dev site link: [Grindstone direct](!itud "Grindstone")',
    '* This search: [](!mas "Omnifocus") will have its link text filled in with the title of the first result.',
    '* This is a wikipedia entry for [Sid Vicious](!wiki)',
    '* This will put the definition of [ambiguous](!def) in the title field of a link to the dictionary entry.',
    '* iTunes Artist search: [BRMC](!iart "Black Rebel Motorcycle Club")',
    '* Site specific search: [Keybindings](!brettterpstra.com "Keybinding Madness")',
    '* [%](!@t ttscoff)',
    '* [%](!@f ttscoff)',
    '* [%](!@m ttscoff@nojack.ca)',
    '* A zero click result [%](!z disambiguation)',
    '* A YouTube search [marked 2 teleprompter](!yt)',
    '* How to spell [balogne](!sp)',
    '* [%](!file brettterpstra header template filename:.afphoto)',
    '* A Firefox history search [GitHub Brett Terpstra](!hfh)',
    '* A Pinboard search for [OWC Express 4M2](!pb)',
    '* An Amazon search [owc express 4m2](!a)',
    'A YouTube embed [marked 2 teleprompter](!yte)'
  ]

  results = [
    'https://apps.apple.com/us/app/marked-2-markdown-preview/id890031187?mt=12',
    'https://flexibits.com/fantastical',
    'https://en.wikipedia.org/wiki/Neat_Neat_Neat',
    'https://podcasts.apple.com/us/podcast/overtired/id944540924?uo=4&app=music&at=10l4tL&ct=searchlink',
    'https://podcasts.apple.com/us/podcast/overtired/id944540924?uo=4&at=10l4tL&ct=searchlink',
    'https://bit.ly/3uEzRKE',
    'https://www.last.fm/music/The+Damned',
    'https://www.last.fm/music/The+Damned/_/Neat+Neat+Neat',
    'https://apps.apple.com/us/app/marked-2-markdown-preview/id890031187?mt=12&uo=4&at=10l4tL&ct=searchlink',
    'http://marked2app.com',
    'https://apps.apple.com/us/app/grindstone/id1357426636?uo=4&at=10l4tL&ct=searchlink',
    'http://www.capybaragames.com/',
    'https://apps.apple.com/us/app/omnifocus-3/id1346203938?mt=12&uo=4&at=10l4tL&ct=searchlink',
    'https://en.wikipedia.org/wiki/Sid_Vicious',
    'https://www.wordnik.com/words/ambiguous',
    'https://music.apple.com/us/artist/black-rebel-motorcycle-club/624658?uo=4&at=10l4tL&ct=searchlink',
    'https://brettterpstra.com/2011/08/13/keybinding-madness/',
    'https://twitter.com/ttscoff',
    'https://www.facebook.com/ttscoff',
    'https://nojack.ca/@ttscoff',
    'https://en.wikipedia.org/wiki/Disambiguation_(disambiguation)',
    %r{https://www\.youtube\.com/watch\?v=[a-z0-9\-_]+}i,
    'bologna',
    'file:///Users/ttscoff/Dropbox/Writing/brettterpstra.com/images/source/BrettTerpstra.com%20Header%20Template/BrettTerpstra.com%20Header%20Template.afphoto',
    'https://github.com/ttscoff/',
    'https://amzn.to/3Vri9qx',
    %r{https://www\.amazon\.com/dp/[A-Z0-9]+/\?ref=as_li_ss_tl&ie=UTF8&linkCode=sl1&tag=},
    %r{iframe width="\d+" height="\d+" src="https://www\.youtube\.com/embed/[a-z0-9\-_]+"}i
  ]

  searches.each_with_index do |search, i|
    describe "executes search for #{search}" do
      it "and returns #{results[i]}" do
        execute_script('bin/searchlink', use_bundler: true, stdin_data: search)
        expect(last_execution).to be_successful

        result = results[i].is_a?(Regexp) ? results[i] : /#{Regexp.escape(results[i])}/
        expect(last_execution.stdout).to match(result)
      end
    end
  end
end
