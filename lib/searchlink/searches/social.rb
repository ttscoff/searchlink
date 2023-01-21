module SL
  class SearchLink
    def social(search_type, search_terms, link_text = '')
      type = 't'
      type = case search_type
             when /^@t/ # twitter-ify username
               return [false, "#{search_terms} is not a valid Twitter handle", link_text] unless search_terms.strip =~ /^@?[0-9a-z_$]+$/i

               't'
             when /^@fb?/ # fb-ify username
               return [false, "#{search_terms} is not a valid Facebook username", link_text] unless search_terms.strip =~ /^@?[0-9a-z_]+$/i

               'f'
             when /^@i/ # intagramify username
               return [false, "#{search_terms} is not a valid Instagram username", link_text] unless search_terms.strip =~ /^@?[0-9a-z_]+$/i

               'i'
             when /^@l/ # linked-inify username
               return [false, "#{search_terms} is not a valid LinkedIn username", link_text] unless search_terms.strip =~ /^@?[0-9a-z_]+$/i

               'l'
             when /^@m/ # mastodonify username
               return [false, "#{search_terms} is not a valid Mastodon username", link_text] unless search_terms.strip =~ /^@?[0-9a-z_]+@[0-9a-z_.]+$/i

               'm'
             end

      url, title = social_handle(type, search_terms)
      link_text = title if link_text == ''
      [url, title, link_text]
    end

    def template_social(user, url, service)

      template = SL.config['social_template'].dup

      template.sub!(/%user%/, user)
      template.sub!(/%service%/, service)
      template.sub!(/%url%/, url.sub(%r{^https?://(www\.)?}, '').sub(%r{/$}, ''))

      template
    end

    def social_handle(type, term)
      handle = term.sub(/^@/, '').strip

      case type
      when /^t/i
        url = "https://twitter.com/#{handle}"
        title = template_social(handle, url, 'Twitter')
      when /^f/i
        url = "https://www.facebook.com/#{handle}"
        title = template_social(handle, url, 'Facebook')
      when /^l/i
        url = "https://www.linkedin.com/in/#{handle}/"
        title = template_social(handle, url, 'LinkedIn')
      when /^i/i
        url = "https://www.instagram.com/#{handle}/"
        title = template_social(handle, url, 'Instagram')
      when /^m/i
        parts = handle.split(/@/)
        return [false, term] unless parts.count == 2

        url = "https://#{parts[1]}/@#{parts[0]}"
        title = template_social(handle, url, 'Mastodon')
      else
        [false, term]
      end

      [url, title]
    end
  end
end
