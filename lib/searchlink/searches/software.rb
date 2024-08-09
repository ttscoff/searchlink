# frozen_string_literal: true

module SL
  # Software Search
  class SoftwareSearch
    class << self
      def settings
        {
          trigger: 's',
          searches: [
            ['s', 'Software Search']
          ]
        }
      end

      def search(_, search_terms, link_text)
        excludes = %w[apple.com postmates.com download.cnet.com softpedia.com softonic.com macupdate.com]
        search_url = %(#{excludes.map { |x| "-site:#{x}" }.join(' ')} #{search_terms} app)

        url, title, link_text = SL.ddg(search_url, link_text)
        link_text = title if link_text == '' && !SL.titleize

        [url, title, link_text]
      end
    end

    SL::Searches.register 'software', :search, self
  end
end
