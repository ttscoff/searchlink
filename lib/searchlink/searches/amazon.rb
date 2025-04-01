# frozen_string_literal: true

module SL
  # Amazon Search
  class AmazonSearch
    class << self
      def settings
        {
          trigger: "a",
          searches: [
            ["a", "Amazon Search"]
          ],
          config: [
            {
              key: "amazon_partner",
              value: "bretttercom-20",
              description: "To create Amazon affiliate links, set amazon_partner to your amazon affiliate tag.",
              required: true
            }
          ]
        }
      end

      def search(_, search_terms, link_text)
        az_url, = SL.ddg("site:amazon.com #{search_terms}", link_text)
        url, title = SL::URL.amazon_affiliatize(az_url, SL.config["amazon_partner"])
        title ||= search_terms

        [url, title, link_text]
      end
    end

    SL::Searches.register "amazon", :search, self
  end
end
