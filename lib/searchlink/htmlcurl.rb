# frozen_string_literal: true

# Class for CURLing an HTML page
class HTMLCurl
  attr_reader :url, :code, :headers, :meta, :links, :head, :body, :title, :description

  def initialize(url, headers: nil, headers_only: false, compressed: false)
    res = curl_html(url, headers: headers, headers_only: headers_only, compressed: compressed)
    @url = res[:url]
    @code = res[:code]
    @headers = res[:headers]
    @meta = res[:meta]
    @links = res[:links]
    @head = res[:head] unless res[:head].nil?
    @body = res[:body]
    @title = @meta['og:title'] || @meta['title'] unless @meta.nil?
    @description = @meta['og:description'] || @meta['description'] unless @meta.nil?
  end

  def meta_tags(head)
    meta = {}
    title = head.match(%r{(?<=<title>)(.*?)(?=</title>)})
    meta['title'] = title.nil? ? nil : title[1]
    refresh = head.match(/http-equiv=(['"])refresh\1(.*?)>/)
    url = refresh.nil? ? nil : refresh[2].match(/url=(.*?)['"]/)
    meta['refresh_url'] = url
    meta_tags = head.scan(/<meta.*?>/)
    meta_tags.each do |tag|
      meta_name = tag.match(/(?:name|property|http-equiv)=(["'])(.*?)\1/)
      next if meta_name.nil?

      meta_value = tag.match(/(?:content)=(['"])(.*?)\1/)
      next if meta_value.nil?

      meta[meta_name[2].downcase] = meta_value[2]
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

  def curl_html(url, headers: nil, headers_only: false, compressed: false)
    flags = 'SsL'
    flags += headers_only ? 'I' : 'i'
    agent = ['Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_3 like Mac OS X; en-us)',
             'AppleWebKit/533.17.9 (KHTML, like Gecko)',
             'Version/5.0.2 Mobile/8J2 Safari/6533.18.5'].join(' ')
    headers = headers.nil? ? '' : headers.map { |h, v| %(-H "#{h}: #{v}") }.join(' ')
    compress = compressed ? '--compressed' : ''
    source = `curl -#{flags} #{compress} #{headers} '#{url}' 2>/dev/null`
    source = `curl -#{flags} #{compress} -A "#{agent}" #{headers} '#{url}' 2>/dev/null` if source.nil? || source.empty?

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
end
