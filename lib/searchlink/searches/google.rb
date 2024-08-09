module SL
  # Google Search
  class GoogleSearch
    class << self
      attr_reader :api_key

      def settings
        {
          trigger: '(g(oo)?g(le?)?|img)',
          searches: [
            ['gg', 'Google Search'],
            ['img', 'First image from result']
          ]
        }
      end

      def test_for_key
        return false unless SL.config.key?('google_api_key') && SL.config['google_api_key']

        key = SL.config['google_api_key']
        return false if key =~ /^(x{4,})?$/i

        @api_key = key

        true
      end

      def search(search_type, search_terms, link_text)
        image = search_type =~ /img$/ ? true : false

        unless test_for_key
          SL.add_error('api key', 'Missing Google API Key')
          return false
        end

        url = "https://customsearch.googleapis.com/customsearch/v1?cx=338419ee5ac894523&q=#{ERB::Util.url_encode(search_terms)}&num=1&key=#{@api_key}"
        json = Curl::Json.new(url).json

        if json['error'] && json['error']['code'].to_i == 429
          SL.notify('api limit', 'Google API limit reached, defaulting to DuckDuckGo')
          return SL.ddg(terms, link_text, google: false, image: image)
        end

        unless json['queries']['request'][0]['totalResults'].to_i.positive?
          SL.notify('no results', 'Google returned no results, defaulting to DuckDuckGo')
          return SL.ddg(terms, link_text, google: false, image: image)
        end

        result = json['items'][0]
        return false if result.nil?

        output_url = result['link']
        output_title = result['title']
        output_title.remove_seo!(output_url) if SL.config['remove_seo']

        output_url = SL.first_image if search_type =~ /img$/

        [output_url, output_title, link_text]
      rescue StandardError
        SL.notify('Google error', 'Error fetching Google results, switching to DuckDuckGo')
        SL.ddg(search_terms, link_text, google: false, image: image)
      end
    end

    SL::Searches.register 'google', :search, self
  end
end
