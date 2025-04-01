# frozen_string_literal: true

# import
require_relative "shorteners/bitly"

# import
require_relative "shorteners/isgd"

# import
require_relative "shorteners/tinyurl"

module SL
  class Shortener
    class << self
      # Displays an AppleScript dialog to confirm shortening a URL.
      #
      # @param url [String] The URL to confirm shortening for.
      # @return [Boolean] True if the user confirms, false otherwise.
      #
      def confirm?(url, title: "Confirm URL?")
        if File.exist?(File.expand_path("~/Library/Services/Preview URL.workflow"))
          cmd = %(osascript -e "display dialog \\"#{url}\\" with title \\"#{title}\\" buttons {\\"Cancel\\", \\"Confirm\\", \\"Preview\\"}")

          res = `#{cmd}`.strip

          if res =~ /Preview/
            path = File.expand_path("~/Library/Services/Preview URL.workflow")
            res = `automator -i "#{url}" "#{path}"`.strip

            return res.empty? ? false : res
          else
            return res =~ /Confirm/
          end
        end

        res = system(%(osascript -e "display dialog \"#{url}\" with title \"#{title}\" buttons {\"Cancel\", \"Confirm\"}"))

        res == 0
      end

      # Shortens a URL using the specified shortener.
      #
      # @param url [String] The URL to shorten.
      # @param shortener [Symbol] The shortener to use (:tinyurl, :bitly, :isgd).
      # @return [String] The shortened URL.
      # @raise [ArgumentError] If the shortener is unknown.
      #
      # @example
      #   SL::Shortener.shorten('http://example.com', :tinyurl)
      #
      def shorten(url, shortener)
        # Check if the URL is already shortened
        return url unless SL::URL.url?(url)

        known_shorteners = %i[tinyurl bitly isgd]
        return url unless known_shorteners.include?(shortener)

        # Confirm shortening the URL
        res = SL::Shortener.confirm?(url)

        return url unless res

        url = res if res.is_a?(String)

        return url unless SL::URL.url?(url)

        # Use the shortener to shorten the URL
        case shortener
        when :tinyurl
          SL::TinyurlSearch.shorten(url)
        when :bitly
          SL::BitlySearch.shorten(url)
        when :isgd
          SL::IsgdSearch.shorten(url)
        else
          raise ArgumentError, "Unknown shortener"
        end
      end
    end
  end
end
