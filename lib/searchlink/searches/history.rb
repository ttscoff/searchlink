#import
require_relative 'chromium'

#import
require_relative 'firefox'

#import
require_relative 'safari'

module SL
  class SearchLink
    def history(search_type, search_terms)
      str = search_type.match(/^h(([scfabe])([hb])?)*$/)[1]
      types = []
      if str =~ /s([hb]*)/
        t = Regexp.last_match(1)
        if t.length > 1 || t.empty?
          types.push('safari_history')
          types.push('safari_bookmarks')
        elsif t == 'h'
          types.push('safari_history')
        elsif t == 'b'
          types.push('safari_bookmarks')
        end
      end

      if str =~ /c([hb]*)/
        t = Regexp.last_match(1)
        if t.length > 1 || t.empty?
          types.push('chrome_bookmarks')
          types.push('chrome_history')
        elsif t == 'h'
          types.push('chrome_history')
        elsif t == 'b'
          types.push('chrome_bookmarks')
        end
      end

      if str =~ /f([hb]*)/
        t = Regexp.last_match(1)
        if t.length > 1 || t.empty?
          types.push('firefox_bookmarks')
          types.push('firefox_history')
        elsif t == 'h'
          types.push('firefox_history')
        elsif t == 'b'
          types.push('firefox_bookmarks')
        end
      end

      if str =~ /e([hb]*)/
        t = Regexp.last_match(1)
        if t.length > 1 || t.empty?
          types.push('edge_bookmarks')
          types.push('edge_history')
        elsif t == 'h'
          types.push('edge_history')
        elsif t == 'b'
          types.push('edge_bookmarks')
        end
      end

      if str =~ /b([hb]*)/
        t = Regexp.last_match(1)
        if t.length > 1 || t.empty?
          types.push('brave_bookmarks')
          types.push('brave_history')
        elsif t == 'h'
          types.push('brave_history')
        elsif t == 'b'
          types.push('brave_bookmarks')
        end
      end

      if str =~ /a([hb]*)/
        t = Regexp.last_match(1)
        if t.length > 1 || t.empty?
          types.push('arc_bookmarks')
          types.push('arc_history')
        elsif t == 'h'
          types.push('arc_history')
        elsif t == 'b'
          types.push('arc_bookmarks')
        end
      end

      search_history(search_terms, types)
    end

    def search_history(term,types = [])
      if types.empty?
        return false unless @cfg['history_types']

        types = @cfg['history_types']
      end

      results = []

      if !types.empty?
        types.each do |type|
          url, title, date = send("search_#{type}", term)

          results << { 'url' => url, 'title' => title, 'date' => date } if url
        end

        if results.empty?
          false
        else
          out = results.sort_by! { |r| r['date'] }.last
          [out['url'], out['title']]
        end
      else
        false
      end
    end
  end
end
