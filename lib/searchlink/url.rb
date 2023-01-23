module SL
  module URL
    class << self
      # Validates that a link exists and returns 200
      def valid_link?(uri_str, limit = 5)
        return false unless uri_str

        SL.notify('Validating', uri_str)
        return false if limit.zero?

        url = URI(uri_str)
        return true unless url.scheme

        url.path = '/' if url.path == ''
        # response = Net::HTTP.get_response(URI(uri_str))
        response = false

        Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == 'https') do |http|
          response = http.request_head(url.path)
        end

        case response
        when Net::HTTPMethodNotAllowed, Net::HTTPServiceUnavailable
          unless /amazon\.com/ =~ url.host
            SL.add_error('link validation', "Validation blocked: #{uri_str} (#{e})")
          end
          SL.notify('Error validating', uri_str)
          true
        when Net::HTTPSuccess
          true
        when Net::HTTPRedirection
          location = response['location']
          valid_link?(location, limit - 1)
        else
          SL.notify('Error validating', uri_str)
          false
        end
      rescue StandardError => e
        SL.notify('Error validating', uri_str)
        SL.add_error('link validation', "Possibly invalid => #{uri_str} (#{e})")
        true
      end

      def url?(input)
        input =~ %r{^(#.*|https?://\S+|/\S+|\S+/|[^!]\S+\.\S+)(\s+".*?")?$}
      end

      def only_url?(input)
        input =~ %r{(?i)^((http|https)://)?([\w\-_]+(\.[\w\-_]+)+)([\w\-.,@?^=%&amp;:/~+#]*[\w\-@^=%&amp;/~+#])?$}
      end

      def ref_title_for_url(url)
        url = URI.parse(url) if url.is_a?(String)

        parts = url.hostname.split(/\./)
        domain = if parts.count > 1
                   parts.slice(-2, 1).join('')
                 else
                   parts.join('')
                 end

        path = url.path.split(%r{/}).last
        if path
          path.gsub!(/-/, ' ').gsub!(/\.\w{2-4}$/, '')
        else
          path = domain
        end

        path.length > domain.length ? path : domain
      end

      def url_to_link(url, type)
        input = url.dup

        if only_url?(input)
          input.sub!(%r{(?mi)^(?!https?://)(.*?)$}, 'https://\1')
          url = URI.parse(input.downcase)

          title = if type == 'ref_title'
                    ref_title_for_url(url)
                  else
                    get_title(url.to_s) || input.sub(%r{^https?://}, '')
                  end

          return [url.to_s, title] if url.hostname
        end
        false
      end

      def amazon_affiliatize(url, amazon_partner)
        return url if amazon_partner.nil? || amazon_partner.empty?

        unless url =~ %r{https?://(?<subdomain>.*?)amazon.com/(?:(?<title>.*?)/)?(?<type>[dg])p/(?<id>[^?]+)}
          return [url, '']
        end

        m = Regexp.last_match
        sd = m['subdomain']
        title = m['title']
        t = m['type']
        id = m['id']
        ["https://#{sd}amazon.com/#{t}p/#{id}/?ref=as_li_ss_tl&ie=UTF8&linkCode=sl1&tag=#{amazon_partner}", title]
      end

      def get_title(url)
        title = nil

        gather = false
        ['/usr/local/bin', '/opt/homebrew/bin'].each do |root|
          if File.exist?(File.join(root, 'gather')) && File.executable?(File.join(root, 'gather'))
            gather = File.join(root, 'gather')
            break
          end
        end

        if gather
          cmd = %(#{gather} --title-only '#{url.strip}' --fallback-title 'Unknown')
          title = SL::Util.exec_with_timeout(cmd, 8)
          if title
            title = title.strip.gsub(/\n+/, ' ').gsub(/ +/, ' ')
            title.remove_seo!(url) if SL.config['remove_seo']
            return title.remove_protocol
          else
            SL.notify('Error retrieving title', 'Gather timed out')
          end
        end

        begin
          # source = %x{/usr/bin/curl -sSL '#{url.strip}'}

          uri = URI.parse(url)
          res = Net::HTTP.get_response(uri)

          if res.code.to_i == 200
            source = res.body
            title = source ? source.match(%r{<title>(.*)</title>}im) : nil

            title = title.nil? ? nil : title[1].strip
          end

          if title.nil? || title =~ /^\s*$/
            SL.add_error('Title not found', "Warning: missing title for #{url.strip}")
            title = url.gsub(%r{(^https?://|/.*$)}, '').gsub(/-/, ' ').strip
          else
            title = title.gsub(/\n/, ' ').gsub(/\s+/, ' ').strip # .sub(/[^a-z]*$/i,'')
            title.remove_seo!(url) if SL.config['remove_seo']
          end

          # Skipping SEO removal until it's more reliable
          # title.remove_seo(url.strip)
          title.remove_protocol
        rescue StandardError
          warn "Error retrieving title for #{url.strip}"
          url.remove_protocol
        end
      end
    end
  end
end
