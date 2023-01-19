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
      when /^@t/ # twitter-ify username
        unless search_terms.strip =~ /^@?[0-9a-z_$]+$/i
          return [false, "#{search_terms} is not a valid Twitter handle", link_text]
        end

        url, title = social_handle('t', search_terms)
        link_text = title
      when /^@fb?/ # fb-ify username
        unless search_terms.strip =~ /^@?[0-9a-z_]+$/i
          return [false, "#{search_terms} is not a valid Facebook username", link_text]
        end

        url, title = social_handle('f', search_terms)
        link_text = title
      when /^@i/ # intagramify username
        unless search_terms.strip =~ /^@?[0-9a-z_]+$/i
          return [false, "#{search_terms} is not a valid Instagram username", link_text]
        end

        url, title = social_handle('i', search_terms)
        link_text = title
      when /^@l/ # linked-inify username
        unless search_terms.strip =~ /^@?[0-9a-z_]+$/i
          return [false, "#{search_terms} is not a valid LinkedIn username", link_text]
        end

        url, title = social_handle('l', search_terms)
        link_text = title
      when /^@m/ # mastodonify username
        unless search_terms.strip =~ /^@?[0-9a-z_]+@[0-9a-z_.]+$/i
          return [false, "#{search_terms} is not a valid Mastodon username", link_text]
        end

        url, title = social_handle('m', search_terms)
        link_text = title
      when /^a$/
        az_url, = ddg("site:amazon.com #{search_terms}")
        url, title = amazon_affiliatize(az_url, @cfg['amazon_partner'])
      when /^am(pod|art|alb|song)?e?$/ # apple music search
        stype = search_type.downcase.sub(/^am/, '')
        otype = 'link'
        if stype =~ /e$/
          otype = 'embed'
          stype.sub!(/e$/, '')
        end
        result = case stype
                 when /^pod$/
                   applemusic(search_terms, 'podcast')
                 when /^art$/
                   applemusic(search_terms, 'music', 'musicArtist')
                 when /^alb$/
                   applemusic(search_terms, 'music', 'album')
                 when /^song$/
                   applemusic(search_terms, 'music', 'musicTrack')
                 else
                   applemusic(search_terms)
                 end

        return [false, "Not found: #{search_terms}", link_text] unless result

        # {:type=>,:id=>,:url=>,:title=>}
        if otype == 'embed' && result[:type] =~ /(album|song)/
          url = 'embed'
          if result[:type] =~ /song/
            link = %(https://embed.music.apple.com/#{@cfg['country_code'].downcase}/album/#{result[:album]}?i=#{result[:id]}&app=music#{@cfg['itunes_affiliate']})
            height = 150
          else
            link = %(https://embed.music.apple.com/#{@cfg['country_code'].downcase}/album/#{result[:id]}?app=music#{@cfg['itunes_affiliate']})
            height = 450
          end

          title = [
            %(<iframe src="#{link}" allow="autoplay *; encrypted-media *;"),
            %(frameborder="0" height="#{height}"),
            %(style="width:100%;max-width:660px;overflow:hidden;background:transparent;"),
            %(sandbox="allow-forms allow-popups allow-same-origin),
            %(allow-scripts allow-top-navigation-by-user-activation"></iframe>)
          ].join(' ')
        else
          url = result[:url]
          title = result[:title]
        end
      when /^b(l|itly)$/
        if url?(search_terms)
          link = search_terms
        else
          link, rtitle = ddg(search_terms)
        end

        url, title = bitly_shorten(link, rtitle)
        link_text = title ? title : url
      when /^def$/ # wikipedia/dictionary search
        # title, definition, definition_link, wiki_link = zero_click(search_terms)
        # if search_type == 'def' && definition_link != ''
        #   url = definition_link
        #   title = definition.gsub(/'+/,"'")
        # elsif wiki_link != ''
        #   url = wiki_link
        #   title = "Wikipedia: #{title}"
        # end
        fix = spell(search_terms)

        if fix && search_terms.downcase != fix.downcase
          add_error('Spelling', "Spelling altered for '#{search_terms}' to '#{fix}'")
          search_terms = fix
          link_text = fix
        end

        url, title = define(search_terms)
      when /^file$/
        url, title = spotlight(search_terms)
        link_text = title
      when /^(g|ddg)$/ # google lucky search
        url, title = ddg(search_terms)
      when /^giste?$/
        url, title = gist(search_terms, search_type)
      when /^hook$/
        url, title = search_hook(search_terms)
      when /^h(([scfabe])([hb])?)*$/
        mtch = Regexp.last_match(1)
        str = mtch
        types = []
        if str =~ /s([hb]*)/
          t = Regexp.last_match(1)
          if t.length > 1 || t.empty?
            types.push('safari_history')
            types.push('safari_bookmarks')
          elsif t == 'h'
            types.push('safari_history')
          elsif t == 'b'
            types.push('safari_bookmarks')
          end
        end

        if str =~ /c([hb]*)/
          t = Regexp.last_match(1)
          if t.length > 1 || t.empty?
            types.push('chrome_bookmarks')
            types.push('chrome_history')
          elsif t == 'h'
            types.push('chrome_history')
          elsif t == 'b'
            types.push('chrome_bookmarks')
          end
        end

        if str =~ /f([hb]*)/
          t = Regexp.last_match(1)
          if t.length > 1 || t.empty?
            types.push('firefox_bookmarks')
            types.push('firefox_history')
          elsif t == 'h'
            types.push('firefox_history')
          elsif t == 'b'
            types.push('firefox_bookmarks')
          end
        end

        if str =~ /e([hb]*)/
          t = Regexp.last_match(1)
          if t.length > 1 || t.empty?
            types.push('edge_bookmarks')
            types.push('edge_history')
          elsif t == 'h'
            types.push('edge_history')
          elsif t == 'b'
            types.push('edge_bookmarks')
          end
        end

        if str =~ /b([hb]*)/
          t = Regexp.last_match(1)
          if t.length > 1 || t.empty?
            types.push('brave_bookmarks')
            types.push('brave_history')
          elsif t == 'h'
            types.push('brave_history')
          elsif t == 'b'
            types.push('brave_bookmarks')
          end
        end

        if str =~ /a([hb]*)/
          t = Regexp.last_match(1)
          if t.length > 1 || t.empty?
            types.push('arc_bookmarks')
            types.push('arc_history')
          elsif t == 'h'
            types.push('arc_history')
          elsif t == 'b'
            types.push('arc_bookmarks')
          end
        end

        url, title = search_history(search_terms, types)
      when /^ialb$/ # iTunes Album Search
        url, title = itunes('album', search_terms, false)
      when /^iart$/ # iTunes Artist Search
        url, title = itunes('musicArtist', search_terms, false)
      when /^imov?$/ # iTunes movie search
        dev = false
        url, title = itunes('movie', search_terms, dev, @cfg['itunes_affiliate'])
      when /^ipod$/
        url, title = itunes('podcast', search_terms, false)
      when /^isong$/ # iTunes Song Search
        url, title = itunes('song', search_terms, false)
      when /^lart$/ # Last.fm Artist Search
        url, title = lastfm('artist', search_terms)
      when /^lsong$/ # Last.fm Song Search
        url, title = lastfm('track', search_terms)
      when /^itud?$/ # iTunes app search
        dev = search_type =~ /d$/
        url, title = itunes('iPadSoftware', search_terms, dev, @cfg['itunes_affiliate'])
      when /^masd?$/ # Mac App Store search (mas = itunes link, masd = developer link)
        dev = search_type =~ /d$/
        url, title = itunes('macSoftware', search_terms, dev, @cfg['itunes_affiliate'])
      when /^pb$/
        url, title = pinboard(search_terms)
      when /^r$/ # simple replacement
        if @cfg['validate_links'] && !valid_link?(search_terms)
          return [false, "Link not valid: #{search_terms}", link_text]
        end

        link_text = search_terms if link_text == ''
        return [search_terms, link_text, link_text]
      when /^s$/ # software search (google)
        excludes = %w[apple.com postmates.com download.cnet.com softpedia.com softonic.com macupdate.com]
        url, title = ddg(%(#{excludes.map { |x| "-site:#{x}" }.join(' ')} #{search_terms} app))
        link_text = title if link_text == '' && !@titleize
      when /^sp(ell)?$/ # replace with spelling suggestion
        res = spell(search_terms)
        return [res, res, ''] if res

        url = false
      when /^te$/
        if url?(search_terms) && search_terms =~ %r{^https://twitter.com/}
          url, title = twitter_embed(search_terms)
        else
          add_error('Invalid Tweet URL', "#{search_terms} is not a valid link to a tweet or timeline")
          url = false
          title = false
        end
      when /^tmdb[amt]?$/
        url, title = tmdb(search_type, search_terms)
        link_text = title if link_text == '' && !@titleize
      when /^wiki$/
        url, title = wiki(search_terms)
      when /^yte?$/
        if url?(search_terms) && search_terms =~ %r{(?:youtu\.be/|youtube\.com/watch\?v=)([a-z0-9_\-]+)$}i
          url = search_terms
        else
          url, title = ddg("site:youtube.com #{search_terms}")
        end

        if search_type =~ /e$/ && url =~ %r{(?:youtu\.be/|youtube\.com/watch\?v=)([a-z0-9_\-]+)$}i
          id = Regexp.last_match(1)
          url = 'embed'
          title = [
            %(<iframe width="560" height="315" src="https://www.youtube.com/embed/#{id}"),
            %(title="YouTube video player" frameborder="0"),
            %(allow="accelerometer; autoplay; clipboard-write; encrypted-media;),
            %(gyroscope; picture-in-picture; web-share"),
            %(allowfullscreen></iframe>)
          ].join(' ')
        end
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
