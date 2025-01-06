# frozen_string_literal: true

# import
require_relative "helpers/chromium"

# import
require_relative "helpers/firefox"

# import
require_relative "helpers/safari"

module SL
  # Browser history/bookmark search
  class HistorySearch
    class << self
      def settings
        {
          trigger: "h(([scfabe])([hb])?)*",
          searches: [
            ["h", "Browser History/Bookmark Search"],
            ["hsh", "Safari History Search"],
            ["hsb", "Safari Bookmark Search"],
            ["hshb", nil],
            ["hsbh", nil],
            ["hch", "Chrome History Search"],
            ["hcb", "Chrome Bookmark Search"],
            ["hchb", nil],
            ["hcbh", nil],
            ["hfh", "Firefox History Search"],
            ["hfb", "Firefox Bookmark Search"],
            ["hfhb", nil],
            ["hfbh", nil],
            ["hah", "Arc History Search"],
            ["hab", "Arc Bookmark Search"],
            ["hahb", nil],
            ["habh", nil],
            ["hbh", "Brave History Search"],
            ["hbb", "Brave Bookmark Search"],
            ["hbhb", nil],
            ["hbbh", nil],
            ["heh", "Edge History Search"],
            ["heb", "Edge Bookmark Search"],
            ["hehb", nil],
            ["hebh", nil]
          ],
          config: [
            {
              description:
                ["Remove or comment (with #) history searches you don't want",
                 "performed by `!h`. You can force-enable them per search, e.g.",
                 "`!hsh` (Safari History only), `!hcb` (Chrome Bookmarks only)",
                 "etc. Multiple types can be strung together: !hshcb (Safari",
                 "History and Chrome bookmarks)"].join(" "),
              required: false,
              key: "history_types",
              value: %w[
                safari_bookmarks
                safari_history
                chrome_history
                chrome_bookmarks
                firefox_bookmarks
                firefox_history
                edge_bookmarks
                edge_history
                brave_bookmarks
                brave_history
                arc_history
                arc_bookmarks
              ]
            }
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        str = search_type.match(/^h(([scfabe])([hb])?)*$/)[1]

        types = []
        while str&.length&.positive?
          if str =~ /^s([hb]*)/
            t = Regexp.last_match(1)
            if t.length > 1 || t.empty?
              types.push("safari_history")
              types.push("safari_bookmarks")
            elsif t == "h"
              types.push("safari_history")
            elsif t == "b"
              types.push("safari_bookmarks")
            end
            str.sub!(/^s([hb]*)/, "")
          end

          if str =~ /^c([hb]*)/
            t = Regexp.last_match(1)
            if t.length > 1 || t.empty?
              types.push("chrome_bookmarks")
              types.push("chrome_history")
            elsif t == "h"
              types.push("chrome_history")
            elsif t == "b"
              types.push("chrome_bookmarks")
            end
            str.sub!(/^c([hb]*)/, "")
          end

          if str =~ /^f([hb]*)$/
            t = Regexp.last_match(1)
            if t.length > 1 || t.empty?
              types.push("firefox_bookmarks")
              types.push("firefox_history")
            elsif t == "h"
              types.push("firefox_history")
            elsif t == "b"
              types.push("firefox_bookmarks")
            end
            str.sub!(/^f([hb]*)/, "")
          end

          if str =~ /^e([hb]*)$/
            t = Regexp.last_match(1)
            if t.length > 1 || t.empty?
              types.push("edge_bookmarks")
              types.push("edge_history")
            elsif t == "h"
              types.push("edge_history")
            elsif t == "b"
              types.push("edge_bookmarks")
            end
            str.sub!(/^e([hb]*)/, "")
          end

          if str =~ /^b([hb]*)$/
            t = Regexp.last_match(1)
            if t.length > 1 || t.empty?
              types.push("brave_bookmarks")
              types.push("brave_history")
            elsif t == "h"
              types.push("brave_history")
            elsif t == "b"
              types.push("brave_bookmarks")
            end
            str.sub!(/^b([hb]*)/, "")
          end

          next unless str =~ /^a([hb]*)$/

          t = Regexp.last_match(1)
          if t.length > 1 || t.empty?
            types.push("arc_bookmarks")
            types.push("arc_history")
          elsif t == "h"
            types.push("arc_history")
          elsif t == "b"
            types.push("arc_bookmarks")
          end
          str.sub!(/^a([hb]*)/, "")
        end

        url, title = search_history(search_terms, types)
        link_text = title if link_text == "" || link_text == search_terms
        [url, title, link_text]
      end

      def search_history(term, types = [])
        if types.empty?
          return false unless SL.config["history_types"]

          types = SL.config["history_types"]
        end

        results = []

        if !types.empty?
          types.each do |type|
            url, title, date = send("search_#{type}", term)

            results << { "url" => url, "title" => title, "date" => date } if url
          end

          if results.empty?
            false
          else
            out = results.sort_by! { |r| r["date"] }.last
            [out["url"], out["title"]]
          end
        else
          false
        end
      end
    end

    SL::Searches.register "history", :search, self
  end
end
