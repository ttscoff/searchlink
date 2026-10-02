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
    BROWSERS = {
      "s" => "safari",
      "c" => "chrome",
      "f" => "firefox",
      "z" => "zen",
      "e" => "edge",
      "b" => "brave",
      "a" => "arc"
    }.freeze

    class << self
      def settings
        {
          trigger: "h(([scfzabe])([hb])?)*",
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
            ["hzh", "Zen History Search"],
            ["hzb", "Zen Bookmark Search"],
            ["hzhb", nil],
            ["hzbh", nil],
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
            ["hebh", nil],
          ],
          config: [
            {
              description: ["Remove or comment (with #) history searches you don't want",
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
                zen_bookmarks
                zen_history
                edge_bookmarks
                edge_history
                brave_bookmarks
                brave_history
                arc_history
                arc_bookmarks
              ],
            },
          ],
        }
      end

      def search(search_type, search_terms, link_text)
        url, title = search_history(search_terms, history_types_for(search_type))
        link_text = title if link_text == ""
        [url, title, link_text]
      end

      # Convert a search type such as "hshcb" into history types. Each browser
      # letter can be followed by "h" (history), "b" (bookmarks), or both;
      # no suffix searches both.
      #
      # @param search_type [String] the search type, e.g. "hzh"
      #
      # @return [Array<String>] history types, e.g. ["zen_history"]
      #
      def history_types_for(search_type)
        types = []
        search_type.sub(/^h/, "").scan(/([scfzeba])([hb]*)/) do |browser, kinds|
          name = BROWSERS[browser]
          case kinds
          when "h" then types.push("#{name}_history")
          when "b" then types.push("#{name}_bookmarks")
          else types.push("#{name}_history", "#{name}_bookmarks")
          end
        end
        types
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
