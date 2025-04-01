# frozen_string_literal: true

module SL
  class PopupSearch
    class << self
      def settings
        {
          trigger: "pop(up)?[gaw]?",
          searches: [
            ["pop", "Popup DuckDuckGo Search"],
            ["popa", "Popup Amazon Search"],
            ["popg", "Popup Google Search"],
            ["popw", "Popup Wikipedia Search"]
          ]
        }
      end

      def search(type, search_terms, link_text)
        return [false, false, link_text] unless workflow_exist?

        term = search_terms.url_encode
        url = case type
              when /g$/
                "https://www.google.com/search?hl=en&q=#{term}"
              when /a$/
                "https://www.amazon.com/s?k=#{term}"
              when /b$/
                "https://www.bing.com/search?q=#{term}"
              when /w$/
                "https://en.wikipedia.org/w/index.php?search=#{term}&title=Special%3ASearch&ns0=1"
              else
                "https://duckduckgo.com/?q=#{term}&ia=web"
              end

        res = `automator -i "#{url}" "#{SL::Util.popup_path}"`.strip

        begin
          if res.empty?
            SL.add_error("Canceled", "Popup Search Cancelled")
            return [false, false, link_text]
          end

          title = SL::URL.title(res)

          link_text = title if link_text == "" && !SL.titleize

          [res, title, link_text]
        rescue StandardError
          false
        end
      end

      private

      def workflow_exist?
        unless SL::Util.popup_path
          SL.add_error("Missing Service", "Preview URL Service not installed")
          return false
        end

        true
      end
    end

    SL::Searches.register "popup", :search, self
  end
end
