#import
require_relative 'searches/pinboard'

#import
require_relative 'searches/applemusic'

#import
require_relative 'searches/itunes'

#import
require_relative 'searches/lastfm'

#import
require_relative 'searches/duckduckgo'

#import
require_relative 'searches/history'

#import
require_relative 'searches/spotlight'

#import
require_relative 'searches/hook'

#import
require_relative 'searches/tmdb'

#import
require_relative 'searches/definition'

#import
require_relative 'searches/spelling'

#import
require_relative 'searches/wikipedia'

#import
require_relative 'searches/bitly'

#import
require_relative 'searches/twitter'

#import
require_relative 'searches/github'

module SL
  class SearchLink
    def available_searches
      searches = [
        %w[a Amazon],
        %w[g Google],
        %w[ddg DuckDuckGo],
        %w[yt YouTube],
        ['z', 'DDG Zero-Click Search'],
        %w[wiki Wikipedia],
        ['s', 'Software search (Google)'],
        ['@t', 'Twitter user link'],
        ['@f', 'Facebook user link'],
        ['@l', 'LinkedIn user link'],
        ['@i', 'Instagram user link'],
        ['@m', 'Mastodon user link'],
        ['am', 'Apple Music'],
        ['amart', 'Apple Music Artist'],
        ['amalb', 'Apple Music Album'],
        ['amsong', 'Apple Music Song'],
        ['ampod', 'Apple Music Podcast'],
        ['ipod', 'iTunes podcast'],
        ['isong', 'iTunes song'],
        ['iart', 'iTunes artist'],
        ['ialb', 'iTunes album'],
        ['lsong', 'Last.fm song'],
        ['lart', 'Last.fm artist'],
        ['mas', 'Mac App Store'],
        ['masd', 'Mac App Store developer link'],
        ['itu', 'iTunes App Store'],
        ['itud', 'iTunes App Store developer link'],
        ['imov', 'iTunes Movies'],
        ['def', 'Dictionary definition'],
        %w[hook Hookmarks],
        ['tmdb', 'The Movie Database search'],
        ['tmdba', 'The Movie Database Actor search'],
        ['tmdbm', 'The Movie Database Movie search'],
        ['tmdbt', 'The Movie Database TV search'],
        %w[sp Spelling],
        %w[pb Pinboard],
        ['h', 'Web history'],
        ['hs[hb]', 'Safari [history, bookmarks]'],
        ['hc[hb]', 'Chrome [history, bookmarks]'],
        ['hf[hb]', 'Firefox [history, bookmarks]'],
        ['he[hb]', 'Edge [history, bookmarks]'],
        ['hb[hb]', 'Brave [history, bookmarks]'],
        ['te', 'Twitter embed'],
        ['file', 'Local file:// link (Spotlight)'],
        ['bl', 'Shorten URL with Bit.ly'],
        ['gist', 'GitHub Gist'],
        ['giste', 'GitHub Gist embed']
      ]
      out = ''
      searches.each { |s| out += "!#{s[0]}#{spacer(s[0])}#{s[1]}\n" }
      out
    end

    def best_search_match(term)
      searches = all_possible_searches.dup
      searches.select do |s|
        s.matches_score(term, separator: '', start_word: false) > 8
      end
    end

    def did_you_mean(term)
      matches = best_search_match(term)
      matches.empty? ? '' : ", did you mean #{matches.map { |m| "!#{m}" }.join(', ')}?"
    end

    def all_possible_searches
      %w[
        @f
        @i
        @l
        @m
        @t
        a
        amalb
        amalbe
        amart
        amarte
        ampod
        ampode
        amsong
        amsonge
        bl
        ddg
        def
        file
        g
        gist
        giste
        h
        ha
        hab
        habh
        hah
        hahb
        hb
        hbb
        hbbh
        hbh
        hbhb
        hc
        hcb
        hcbh
        hch
        hchb
        he
        heb
        hebh
        heh
        hehb
        hf
        hfb
        hfbh
        hfh
        hfhb
        hook
        hs
        hsb
        hsbh
        hsh
        hshb
        ialb
        ialbe
        iart
        iarte
        imov
        ipod
        ipode
        isong
        isonge
        itu
        itud
        lalb
        lalbe
        lart
        larte
        lpod
        lpode
        lsong
        lsonge
        mas
        masd
        pb
        r
        s
        sp
        spell
        te
        tmdb
        tmdba
        tmdbm
        tmdbt
        wiki
        yt
        yte
        z
        zero
      ].concat(@cfg['custom_site_searches'].keys)
    end

    def valid_searches
      [
        'h(([scfabe])([hb])?)*',
        'a',
        'imov',
        'g',
        'ddg',
        'z(ero)?',
        'wiki',
        'def',
        'masd?',
        'itud?',
        'tmdb[amt]?',
        's',
        '(i|am|l)(art|alb|song|pod)e?',
        '@[tfilm]',
        'r',
        'sp(ell)?',
        'pb',
        'yte?',
        'te',
        'file',
        'b(l|itly)',
        'giste?',
        'hook'
      ]
    end

    def valid_search?(term)
      valid = false
      valid = true if term =~ /^(#{valid_searches.join('|')})$/
      valid = true if @cfg['custom_site_searches'].keys.include? term
      notify("Invalid search#{did_you_mean(term)}", term) unless valid
      valid
    end
  end
end
