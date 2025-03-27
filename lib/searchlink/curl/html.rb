# frozen_string_literal: true

module Curl
  # String helpers
  class ::String
    def remove_entities
      gsub(/&nbsp;/, " ")
    end
  end

  # Class for CURLing an HTML page
  class Html
    attr_reader :url, :code, :headers, :meta, :links, :head, :body,
                :source, :title, :description, :body_links, :body_images

    ##
    ## Create a new page object from a URL
    ##
    ## @param      url           [String] The url
    ## @param      headers       [Hash] The headers to use in the curl call
    ## @param      headers_only  [Boolean] Return headers only
    ## @param      compressed    [Boolean] Expect compressed result
    ##
    ## @return     [HTMLCurl] new page object
    ##
    def initialize(url, headers: nil, headers_only: false, compressed: false)
      @curl = TTY::Which.which("curl")
      res = curl_html(url, headers: headers, headers_only: headers_only, compressed: compressed)
      @url = res[:url]
      @code = res[:code]
      @headers = res[:headers]
      @meta = res[:meta]
      @links = res[:links]
      @head = res[:head] unless res[:head].nil?
      @body = reencode(res[:body])
      @source = res[:source]
      @title = @meta["og:title"] || @meta["title"] unless @meta.nil?
      @description = @meta["og:description"] || @meta["description"] unless @meta.nil?
      @body_links = content_links
      @body_images = content_images
    end

    ##
    ## Extract text between two regular expressions
    ##
    ## @param      before  [String, Regexp] The before
    ## @param      after   [String, Regexp] The after
    ##
    ## @return     [Array] array of matches
    ##
    def extract(before, after)
      before = /#{Regexp.escape(before)}/ unless before.instance_of?(Regexp)
      after = /#{Regexp.escape(after)}/ unless after.instance_of?(Regexp)
      @body.scan(/#{before.source}(.*?)#{after.source}/)
    end

    ##
    ## Extract an array of tags or tag attributes
    ##
    ## @param      tag        [String] The tag
    ## @param      attribute  [String] The attribute
    ## @param      source     [Boolean] Return full tag source
    ##                        (negates attribute if true)
    ## @param      content    [Boolean] Return only tag
    ##                        contents
    ##
    ## @return     [Hash, Array] if source, return array of full
    ##             tags, if content, return array of tag contents,
    ##             otherwise, return a hash of tags including
    ##             attributes and content
    ##
    ## If attribute is not given, tag contents will be returned
    ##
    ## @example    page.extract_tag('h1') => [Array of h1 tag
    ## contents]
    ## @example    page.extract_tag('img', 'src') => [Array of img
    ## src attributes]
    ##
    def extract_tag(tag, attribute = nil, source: false, content: false)
      res = extract_tag_contents(tag, source: true)

      return res if source

      res.map! do |tag_source|
        m = tag_source.to_enum(:scan, /(\S+)=(['"])(.*?)\2/).map { Regexp.last_match }
        attrs = m.each_with_object({}) { |at, a| a[at[1]] = at[3] }
        tags = tag_source.match(/<.*?>(?<content>.*?)</)
        contents = tags.nil? ? nil : tags["content"]
        {
          tag: tag,
          source: tag_source,
          attrs: attrs,
          content: contents
        }
      end

      return res.map { |r| r[:content] } if content

      return res if attribute.nil?

      res.map { |r| r[:attrs][attribute] }
    end

    ##
    ## Extract tag contents or full tag source
    ##
    ## @param      tag     The tag
    ## @param      source  [Boolean] Return full tag instead of contents
    ##
    ## @return [Array] array of tag matches/contents
    def extract_tag_contents(tag, source: false)
      return @body.scan(%r{<#{tag}.*?>(?:.*?</#{tag}>)?}) if source

      @body.scan(/<#{tag}.*?>(.*?)</).map { |t| t[1] }
    end

    ##
    ## Return all tags in body, or a specific tag
    ##
    ## @param      tag   [String, Array] The tag to return,
    ##                   can be an array
    ##
    ## @return     [Array] Array of tags. If no tag is specified, a
    ##             hierarchical array of all tags in the document
    ##             is returned. If one or more tags are specified,
    ##             return a flattened list in document order.
    ##
    def tags(tag = nil)
      tags = content_tags(@body)
      return tags if tag.nil?

      tag = [tag] unless tag.is_a?(Array)
      tag.map!(&:downcase)
      flatten_tags(tags).dup.delete_if { |t| !tag.include?(t[:tag].downcase) }
    end

    ##
    ## Get all images from the page
    ##
    ## @return     [Array] Array of images, both from picture sources and img tags
    ##
    def images
      output = []
      %w[og:image twitter:image].each do |src|
        next unless @meta.key?(src)

        output << {
          type: "opengraph",
          attrs: nil,
          src: @meta[src]
        }
      end
      images = tags(%w[img source])
      images.each do |img|
        case img[:tag].downcase
        when /source/
          srcsets = img[:attrs].filter { |k| k[:key] =~ /srcset/i }
          if srcsets.count.positive?
            srcset = []
            srcsets.each do |src|
              src[:value].split(/ *, */).each do |s|
                image, media = s.split(/ /)
                srcset << {
                  src: image,
                  media: media
                }
              end
            end
            output << {
              type: "srcset",
              attrs: img[:attrs],
              images: srcset
            }
          end
        when /img/
          output << {
            type: "img",
            src: img[:attrs].filter { |a| a[:key] =~ /src/i }.first[:value],
            attrs: img[:attrs]
          }
        end
      end
      output
    end

    def to_s
      headers = @headers.nil? ? 0 : @headers.count
      meta = @meta.nil? ? 0 : @meta.count
      links = @links.nil? ? 0 : @links.count
      [
        %(<HTMLCurl: @code="#{@code}" @url="#{@url}" @title="#{@title}"),
        %(@description=#{@description} @headers:#{headers} @meta:#{meta} @links:#{links}>)
      ].join(" ")
    end

    ##
    ## Return all headers of given level
    ##
    ## @param      level  [Number] The level (1-6)
    ##
    ## @return [Array] array of headers with text and all tag attributes as symbols
    ##
    def h(level = '\d')
      res = []
      headlines = @body.to_enum(:scan, %r{<h(?<level>#{level})(?<tag> .*?)?>(?<text>.*?)</h#{level}>}i).map { Regexp.last_match }
      headlines.each do |m|
        headline = { level: m["level"] }
        if m["tag"].nil?
          attrs = nil
        else
          attrs = m["tag"].to_enum(:scan, /(?<attr>\w+)=(?<quot>["'])(?<content>.*?)\k<quot>/).map { Regexp.last_match }
          attrs.each { |a| headline[a["attr"].to_sym] = a["content"] }
        end
        headline[:text] = m["text"].remove_entities
        res << headline
      end
      res
    end

    private

    ##
    ## Flatten the array of tags
    ##
    ## @param      tags  [Array] Document tags
    ##
    def flatten_tags(tags)
      flattened = []

      tags.each do |t|
        flattened << { tag: t[:tag], attrs: t[:attrs], content: t[:content] }
        flattened.concat(flatten_tags(t[:tags])) unless t[:tags].nil?
      end

      flattened
    end

    ##
    ## Return an array of all tags in the content
    ##
    ## @param      content  [String] The content to parse
    ##
    def content_tags(content)
      return nil if content.nil?

      res = content.to_enum(:scan, %r{(?mix)
        <(?<tag>(?!</)[a-z0-9]+)(?<attrs>\s[^>]+)?
        (?:\s*/>|>(?<content>.*?)</\k<tag>>)}).map { Regexp.last_match }
      res.map do |tag|
        if tag["attrs"].nil?
          attrs = nil
        else
          attrs = tag["attrs"].strip.to_enum(:scan, /(?ix)
                                             (?<key>[@a-z0-9-]+)(?:=(?<quot>["'])
                                             (?<value>[^"']+)\k<quot>|[ >])?/i).map { Regexp.last_match }
          attrs.map! { |a| { key: a["key"], value: a["key"] =~ /^(class|rel)$/ ? a["value"].split(/ /) : a["value"] } }
        end
        {
          tag: tag["tag"],
          source: tag.to_s,
          attrs: attrs,
          content: tag["content"],
          tags: content_tags(tag["content"])
        }
      end
    end

    ##
    ## Extract all meta tags from the document head
    ##
    ## @param      head [String] The head content
    ##
    ## @return     [Hash] hash of meta tags and values
    ##
    def meta_tags(head)
      meta = {}
      title = head.match(%r{(?<=<title>)(.*?)(?=</title>)})
      meta["title"] = title.nil? ? nil : title[1]
      refresh = head.match(/http-equiv=(['"])refresh\1(.*?)>/)
      url = refresh.nil? ? nil : refresh[2].match(/url=(.*?)['"]/)
      meta["refresh_url"] = url
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

    ##
    ## Extract all <link> tags from head
    ##
    ## @param      head  [String] The head content
    ##
    ## @return     [Array] Array of links
    ##
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

    ##
    ## Get all links in the body of the page
    ##
    ## @return     [Array] array of links with href, title,
    ##             rel, text and class
    ##
    def content_links
      links = []
      link_tags = @body.to_enum(:scan, %r{<a (?<tag>.*?)>(?<text>.*?)</a>}).map { Regexp.last_match }
      link_tags.each do |m|
        href = m["tag"].match(/href=(["'])(.*?)\1/)
        href = href[2] unless href.nil?
        title = m["tag"].match(/title=(["'])(.*?)\1/)
        title = title[2] unless title.nil?
        rel = m["tag"].match(/rel=(["'])(.*?)\1/)
        rel = rel[2] unless rel.nil?
        link_class = m["tag"].match(/class=(["'])(.*?)\1/)
        link_class = link_class[2] unless link_class.nil?
        text = m["text"].remove_entities
        link = {
          href: href,
          title: title,
          rel: rel,
          text: text,
          class: link_class
        }
        links << link
      end
      links
    end

    ##
    ## Get all img tags in the body of the page
    ##
    ## @return     [Array] array of images with src and all attributes
    ##
    def content_images
      images = []
      image_tags = @body.to_enum(:scan, %r{<img (?<tag>.*?)/?>}).map { Regexp.last_match }
      image_tags.each do |m|
        attrs = m["tag"].to_enum(:scan, /(?<attr>\w+)=(?<quot>["'])(?<content>.*?)\k<quot>/).map { Regexp.last_match }
        image = {}
        attrs.each { |a| image[a["attr"].to_sym] = a["content"] }
        images << image
      end
      images
    end

    ##
    ## Curls the html for the page
    ##
    ## @param      url           [String] The url
    ## @param      headers       [Hash] The headers
    ## @param      headers_only  [Boolean] Return headers only
    ## @param      compressed    [Boolean] expect compressed results
    ##
    ## @return     [Hash] hash of url, code, headers, meta, links, head, body, and source
    ##
    def curl_html(url, headers: nil, headers_only: false, compressed: false)
      flags = "SsL"
      flags += headers_only ? "I" : "i"
      agent = ["Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_3 like Mac OS X; en-us)",
               "AppleWebKit/533.17.9 (KHTML, like Gecko)",
               "Version/5.0.2 Mobile/8J2 Safari/6533.18.5"].join(" ")
      headers = headers.nil? ? "" : headers.map { |h, v| %(-H "#{h}: #{v}") }.join(" ")
      compress = compressed ? "--compressed" : ""
      source = `#{@curl} -#{flags} #{compress} #{headers} '#{url}' 2>/dev/null`
      if source.nil? || source.empty?
        source = `#{@curl} -#{flags} #{compress} -A "#{agent}" #{headers} '#{url}' 2>/dev/null`
      end

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

      if headers["content-type"] =~ /json/
        return { url: url, code: code, headers: headers, meta: nil, links: nil, head: nil, body: source.strip, source: source.strip, body_links: nil, body_images: nil }
      end

      head = source.match(%r{(?<=<head>)(.*?)(?=</head>)}mi)

      if head.nil?
        { url: url, code: code, headers: headers, meta: nil, links: nil, head: nil, body: source.strip, source: source.strip, body_links: nil, body_images: nil }
      else
        meta = meta_tags(head[1])
        links = link_tags(head[1])
        body = source.match(%r{<body.*?>(.*?)</body>}mi)[1]
        { url: url, code: code, headers: headers, meta: meta, links: links, head: head[1], body: body, source: source.strip, body_links: body_links, body_images: body_images }
      end
    end

    ##
    ## Reencode the content (borrowed from Nokogiri)
    ##
    ## @param      body          [String] The body
    ## @param      content_type  [String] Force content type
    ##
    def reencode(body, content_type = nil)
      if body.encoding == Encoding::ASCII_8BIT
        encoding = nil

        # look for a Byte Order Mark (BOM)
        initial_bytes = body[0..2].bytes
        if initial_bytes[0..2] == [0xEF, 0xBB, 0xBF]
          encoding = Encoding::UTF_8
        elsif initial_bytes[0..1] == [0xFE, 0xFF]
          encoding = Encoding::UTF_16BE
        elsif initial_bytes[0..1] == [0xFF, 0xFE]
          encoding = Encoding::UTF_16LE
        end

        # look for a charset in a content-encoding header
        encoding ||= content_type[/charset=["']?(.*?)($|["';\s])/i, 1] if content_type

        # look for a charset in a meta tag in the first 1024 bytes
        unless encoding
          data = body[0..1023].gsub(/<!--.*?(-->|\Z)/m, "")
          data.scan(/<meta.*?>/im).each do |meta|
            encoding ||= meta[/charset=["']?([^>]*?)($|["'\s>])/im, 1]
          end
        end

        # if all else fails, default to the official default encoding for HTML
        encoding ||= Encoding::ISO_8859_1

        # change the encoding to match the detected or inferred encoding
        body = body.dup
        begin
          body.force_encoding(encoding)
        rescue ArgumentError
          body.force_encoding(Encoding::ISO_8859_1)
        end
      end

      body.encode(Encoding::UTF_8)
    end
  end
end
