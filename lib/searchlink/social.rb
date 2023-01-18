module SL
  class SearchLink
    def template_social(user, url, service)
      template = @cfg['social_template']
      template.sub!(/%user%/, user)
      template.sub!(/%service%/, service)
      template.sub!(/%url%/, url.sub(%r{^https?://(www\.)?}, '').sub(%r{/$}, ''))
      template
    end

    def social_handle(type, term)
      handle = term.sub(/^@/, '').strip
      case type
      when /^t/
        url = "https://twitter.com/#{handle}"
        title = template_social(handle, url, 'Twitter')
      when /^f/
        url = "https://www.facebook.com/#{handle}"
        title = template_social(handle, url, 'Facebook')
      when /^l/
        url = "https://www.linkedin.com/in/#{handle}/"
        title = template_social(handle, url, 'LinkedIn')
      when /^i/
        url = "https://www.instagram.com/#{handle}/"
        title = template_social(handle, url, 'Instagram')
      when /^m/
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
