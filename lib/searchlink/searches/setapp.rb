# frozen_string_literal: true

# Setapp Plugin
# Takes an app name or Setapp URL, adds an affiliate string,
# and outputs a URL, optionally shortened with is.gd or bit.ly
#
# Optional config:
#
# ```yaml
# setapp_affiliate_string: xxxxxxxxx # see below
# bitly_domain: bit.ly # or custom domain
# bitly_access_token: xxxxxxxxxxxx # see below
# ```
#
# To get your Setapp affiliate string
#
# 1. You must have a Setapp affiliate account through impact.com
# 2. Generate a campaign url for an app landing page
# 3. Follow the short link provided
# 4. The browser URL bar will now show the expanded link
# 5. Copy everything after the & symbol in the url to
#    the `setapp_affiliate_string` config line
#
# Run a search with !set, !seti, or !setb. The input can either be
# a Setapp app landing page url, or an app name, e.g. `!seti marked`,
# `[jump desktop](!seti)`, or `!setb https://setapp.com/apps/marked`
#
module SL
  # is.gd link shortening
  class SetappSearch
    class << self
      def settings
        {
          trigger: "set[ib]?",
          searches: [
            ["set", "Setapp Link with optional affiliate string"],
            ["seti", "Shorten Setapp Affiliate Link with is.gd"],
            ["setb", "Shorten Setapp Affiliate Link with bit.ly"]
          ],
          config: [
            {
              description: "Setapp affiliate string (optional).\nYou can find your affiliate string here: https://www.impact.com/affiliate/links",
              key: "setapp_affiliate_string",
              value: "''",
              required: false
            }
          ]
        }
      end

      def search(search_type, search_terms, link_text)
        link = build_link(search_terms)
        link, rtitle, link_text = process_link(link, search_terms, link_text)
        return [false, rtitle, link_text] unless valid_setapp_url?(link)

        process_search_type(search_type, link, rtitle, link_text)
      end

      private

      def build_link(search_terms)
        return search_terms if SL::URL.url?(search_terms)

        "https://setapp.com/apps/#{CGI.escape(search_terms.gsub(/ \d+$/, '').gsub(/ +/, '-').downcase)}"
      end

      def process_link(link, search_terms, link_text)
        SL::URL.valid_link?(link, 2) && [link, search_terms, link_text] || SL.ddg("site:setapp.com #{search_terms}", link_text)
      end

      def process_search_type(search_type, link, title, link_text)
        link_text = link_text.nil? || link_text.empty? ? Curl::Html.new(link).title.sub(/ on Setapp.*/, "") : link_text
        link = build_affiliate_url(link)
        case search_type
        when "set"
          format_response(link, link_text)
        when "seti"
          shorten(:isgd, link, title, link_text)
        when "setb"
          shorten(:bitly, link, title, link_text)
        else
          SL.add_error("Invalid search type", "Search error")
          [false, title, link_text]
        end
      end

      def shorten(type, url, title = nil, link_text = nil)
        return [false, title, link_text] unless valid_setapp_url?(url)

        shortened_url = case type
                        when :isgd
                          SL::IsgdSearch.shorten(url)
                        when :bitly
                          SL::BitlySearch.shorten(url)
                        end
        return [false, title, link_text] unless shortened_url

        format_response(shortened_url, link_text)
      end

      def valid_setapp_url?(url)
        return true if SL::URL.valid_link?(url, 2) && url =~ %r{^https://setapp.com}

        SL.add_error("URL is not a valid Setapp link", "URL error")
        false
      end

      def valid_affiliate_config?
        return true if SL.config.key?("setapp_affiliate_string") && !SL.config["setapp_affiliate_string"].empty?

        # SL.add_error("Setapp affiliate string not configured", "Missing affiliate string")
        false
      end

      def build_affiliate_url(url)
        return url unless valid_affiliate_config?

        separator = url =~ /\?/ ? "&" : "?"
        "#{url}#{SL.config['setapp_affiliate_string'].sub(/^[?&]?/, separator)}"
      end

      def format_response(link, link_text)
        title = SL::URL.title(link)

        [link, title, link_text.nil? || link_text.empty? && !SL.titleize ? title : link_text]
      end
    end

    SL::Searches.register "setapp", :search, self
  end
end
