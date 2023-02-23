# Main SearchLink class
module SL
  include URL

  class SearchLink
    include Plist

    attr_reader :originput, :output, :clipboard

    private

    #
    # Run a search
    #
    # @param [String] search_type search abbreviation
    # @param [String] search_terms search terms
    # @param [String] link_text text of link
    # @param [Number] search_count Iteration count
    #
    # @return [Array] [Url, link, text]
    #
    def do_search(search_type, search_terms, link_text = '', search_count = 0)
      if (search_count % 5).zero?
        SL.notify('Throttling for 5s')
        sleep 5
      end

      description = SL::Searches.description_for_search(search_type)

      SL.notify(description, search_terms)
      return [false, search_terms, link_text] if search_terms.empty?

      if SL::Searches.valid_search?(search_type)
        url, title, link_text = SL::Searches.do_search(search_type, search_terms, link_text)
      else
        case search_type
        when /^r$/ # simple replacement
          if SL.config['validate_links'] && !SL::URL.valid_link?(search_terms)
            return [false, "Link not valid: #{search_terms}", link_text]
          end

          title = SL::URL.get_title(search_terms) || search_terms

          link_text = title if link_text == ''
          return [search_terms, title, link_text]
        else
          if search_terms
            if search_type =~ /.+?\.\w{2,}$/
              url, title, link_text = SL.ddg(%(site:#{search_type} #{search_terms}), link_text)
            else
              url, title, link_text = SL.ddg(search_terms, link_text)
            end
          end
        end
      end

      if link_text == ''
        link_text = SL.titleize ? title : search_terms
      end

      if url && SL.config['validate_links'] && !SL::URL.valid_link?(url) && search_type !~ /^sp(ell)?/
        [false, "Not found: #{url}", link_text]
      elsif !url
        [false, "No results: #{url}", link_text]
      else
        [url, title, link_text]
      end
    end
  end
end
