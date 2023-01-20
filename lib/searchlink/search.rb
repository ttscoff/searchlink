# Main SearchLink class
module SL
  class SearchLink
    include Plist

    attr_reader :originput, :output, :clipboard

    private

    def notify(str, sub)
      return unless @cfg['notifications']

      `osascript -e 'display notification "SearchLink" with title "#{str}" subtitle "#{sub}"'`
    end

    def do_search(search_type, search_terms, link_text = '', search_count = 0)
      if (search_count % 5).zero?
        notify('Throttling for 5s')
        sleep 5
      end

      notify('Searching', search_terms)
      return [false, search_terms, link_text] if search_terms.empty?

      case search_type
      when /^@(t|fb?|i|l|m)$/
        url, title, link_text = social(search_type, search_terms, link_text)
      when /^a$/
        url, title = amazon(search_terms)
      when /^am(pod|art|alb|song)?e?$/ # apple music search
        url, title, link_text = am(search_type, search_terms, link_text)
      when /^b(l|itly)$/
        url, title, link_text = bitly(search_type, search_terms)
      when /^def$/ # wikipedia/dictionary search
        url, title, link_text = dictionary(search_type, search_terms, link_text)
      when /^file$/
        url, title, link_text = spotlight(search_terms)
      when /^(g|ddg)$/ # google lucky search
        url, title = ddg(search_terms)
      when /^giste?$/
        url, title = gist(search_terms, search_type)
      when /^hook$/
        url, title = search_hook(search_terms)
      when /^h(([scfabe])([hb])?)*$/
        url, title = history(search_type, search_terms)
      when /^(ialb|iart|imov?|ipod|isong|itud?|masd?)$/
        url, title = itunes(search_type, search_terms)
      when /^lart$/ # Last.fm Artist Search
        url, title = lastfm('artist', search_terms)
      when /^lsong$/ # Last.fm Song Search
        url, title = lastfm('track', search_terms)
      when /^pb$/
        url, title = pinboard(search_terms)
      when /^r$/ # simple replacement
        if @cfg['validate_links'] && !valid_link?(search_terms)
          return [false, "Link not valid: #{search_terms}", link_text]
        end

        link_text = search_terms if link_text == ''
        return [search_terms, link_text, link_text]
      when /^s$/ # software search (google)
        url, title, link_text = software(search_type, search_terms, link_text)
      when /^sp(ell)?$/ # replace with spelling suggestion
        res = spell(search_terms)
        return [res, res, ''] if res

        url = false
      when /^te$/
        url, title = twitter(search_type, search_terms)
      when /^tmdb[amt]?$/
        url, title, link_text = tmdb(search_type, search_terms, link_text)
      when /^wiki$/
        url, title = wiki(search_terms)
      when /^yte?$/
        url, title = youtube(search_type, search_terms)
      when /^z(ero)?$/
        url, title = zero_click(search_terms)
      else
        if search_terms
          if search_type =~ /.+?\.\w{2,}$/
            url, title = ddg(%(site:#{search_type} #{search_terms}))
          else
            url, title = ddg(search_terms)
          end
        end
      end

      if link_text == ''
        link_text = @titleize ? title : search_terms
      end

      if url && @cfg['validate_links'] && !valid_link?(url) && search_type !~ /^sp(ell)?/
        [false, "Not found: #{url}", link_text]
      elsif !url
        [false, "No results: #{url}", link_text]
      else
        [url, title, link_text]
      end
    end
  end
end
