module SL
  module Util
    class << self
      def meta_tags(head)
        meta = {}
        title = head.match(%r{(?<=<title>)(.*?)(?=</title>)})
        meta['title'] = title.nil? ? nil : title[1]
        refresh = head.match(/http-equiv=(['"])refresh\1(.*?)>/)
        url = refresh.nil? ? nil : refresh[2].match(/url=(.*?)['"]/)
        meta['refresh_url'] = url
        meta_tags = head.scan(/<meta.*?>/)
        meta_tags.each do |tag|
          meta_name = tag.match(/(?:name|property)=(["'])(.*?)\1/)
          next if meta_name.nil?

          meta_value = tag.match(/(?:content)=(['"])(.*?)\1/)
          next if meta_value.nil?

          meta[meta_name[2]] = meta_value[2]
        end
        meta
      rescue StandardError => e
        warn e
        {}
      end

      def link_tags(head)
        links = []
        link_tags = head.scan(/<link.*?>/)
        link_tags.each do |tag|
          link_rel = tag.match(/rel=(['"])(.*?)\1/)
          link_rel = link_rel.nil? ? nil : link_rel[2]

          next if link_rel =~ /preload/

          link_href = tag.match(/href=(["'])(.*?)\1/)
          next if link_href.nil?

          link_href = link_href[2]

          link_title = tag.match(/title=(['"])(.*?)\1/)
          link_title = link_title.nil? ? nil : link_title[2]

          link_type = tag.match(/type=(['"])(.*?)\1/)
          link_type = link_type.nil? ? nil : link_type[2]

          links << { rel: link_rel, href: link_href, type: link_type, title: link_title }
        end
        links
      end

      def curlJSON(url, headers: nil, compressed: false)
        res = curlHTML(url, headers: headers, compressed: compressed)
        json = res[:body].force_encoding('utf-8')

        # json.gsub!(/[^[:ascii:]]/) do |non_ascii|
        #   non_ascii.force_encoding('utf-8')
        #            .encode('utf-16be')
        #            .unpack('H*')
        #            .gsub(/(....)/, '\u\1')
        # end

        json.gsub!(/[\u{1F600}-\u{1F6FF}]/, '')
        JSON.parse(json)
      rescue StandardError => e
        warn e
        warn e.backtrace
        nil
      end

      def curlHTML(url, headers: nil, headers_only: false, compressed: false)
        flags = 'SsL'
        flags += headers_only ? 'I' : 'i'
        agent = ['Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_3 like Mac OS X; en-us)',
                 'AppleWebKit/533.17.9 (KHTML, like Gecko)',
                 'Version/5.0.2 Mobile/8J2 Safari/6533.18.5'].join(' ')
        headers = headers.nil? ? '' : headers.map { |h| %(-H "#{h}") }.join(' ')
        compress = compressed ? '--compressed' : ''
        source = `curl -#{flags} #{compress} -A "#{agent}" #{headers} '#{url}' 2>/dev/null`
        source = `curl -#{flags} #{compress} #{headers} '#{url}' 2>/dev/null` if source.nil? || source.empty?

        return false if source.nil? || source.empty?

        source.strip!

        headers = {}
        lines = source.split(/\r\n/)
        code = lines[0].match(/(\d\d\d)/)[1]
        lines.shift
        lines.each_with_index do |line, idx|
          if line =~ /^([\w-]+): (.*?)$/
            m = Regexp.last_match
            headers[m[1]] = m[2]
          else
            source = lines[idx..].join("\n")
            break
          end
        end

        if headers['content-type'] =~ /json/
          return { url: url, code: code, headers: headers, meta: nil, links: nil, head: nil, body: source.strip }
        end

        head = source.match(%r{(?<=<head>)(.*?)(?=</head>)}mi)

        if head.nil?
          { url: url, code: code, headers: headers, meta: nil, links: nil, head: nil, body: source.strip }
        else
          meta = meta_tags(head[1])
          links = link_tags(head[1])
          body = source.match(%r{<body.*?>(.*?)</body>}mi)[1]
          { url: url, code: code, headers: headers, meta: meta, links: links, head: head[1], body: body }
        end
      end

      ## Execute system command with deadman's switch
      ##
      ## <https://stackoverflow.com/questions/8292031/ruby-timeouts-and-system-commands>
      ## <https://stackoverflow.com/questions/12189904/fork-child-process-with-timeout-and-capture-output>
      ##
      ## @param      cmd      The command to execute
      ## @param      timeout  The timeout
      ##
      ## @return     [String] STDOUT output
      ##
      def exec_with_timeout(cmd, timeout)
        begin
          # stdout, stderr pipes
          rout, wout = IO.pipe
          rerr, werr = IO.pipe
          stdout, stderr = nil

          pid = Process.spawn(cmd, pgroup: true, out: wout, err: werr)

          Timeout.timeout(timeout) do
            Process.waitpid(pid)

            # close write ends so we can read from them
            wout.close
            werr.close

            stdout = rout.readlines.join
            stderr = rerr.readlines.join
          end
        rescue Timeout::Error
          Process.kill(-9, pid)
          Process.detach(pid)
        ensure
          wout.close unless wout.closed?
          werr.close unless werr.closed?
          # dispose the read ends of the pipes
          rout.close
          rerr.close
        end

        stdout&.strip
      end

      ##
      ## Execute a search with deadman's switch
      ##
      ## @param      search   [Proc] The search command
      ## @param      timeout  [Number] The timeout
      ##
      ## @return     [Array] url, title, link_text
      ##
      def search_with_timeout(search, timeout)
        url = nil
        title = nil
        link_text = nil

        begin
          Timeout.timeout(timeout) do
            url, title, link_text = search.call
          end
        rescue Timeout::Error
          SL.add_error('Timeout', 'Search timed out')
          url, title, link_text = false
        end

        [url, title, link_text]
      end

      ##
      ## Get the path for a cache file
      ##
      ## @param      filename  [String]  The filename to
      ##                       generate the cache for
      ##
      ## @return     [String] path to new cache file
      ##
      def cache_file_for(filename)
        cache_folder = File.expand_path('~/.local/share/searchlink/cache')
        FileUtils.mkdir_p(cache_folder) unless File.directory?(cache_folder)
        File.join(cache_folder, filename.sub(/(\.cache)?$/, '.cache'))
      end
    end
  end
end
