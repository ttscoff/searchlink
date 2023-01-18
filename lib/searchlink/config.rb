module SL
  # Main SearchLink class
  class SearchLink
    attr_accessor :cfg

    # Values found in ~/.searchlink will override defaults in
    # this script

    def initialize(opt = {})
      @printout = opt[:echo] || false
      unless File.exist? File.expand_path('~/.searchlink')
        default_config = <<~ENDCONFIG
          # set to true to have an HTML comment included detailing any errors
          # Can be disabled per search with `--d`, or enabled with `++d`.
          debug: true
          # set to true to have an HTML comment included reporting results
          report: true

          # use Notification Center to display progress
          notifications: false

          # when running on a file, back up original to *.bak
          backup: true

          # change this to set a specific country for search (default US)
          country_code: US

          # set to true to force inline Markdown links. Can be disabled
          # per search with `--i`, or enabled with `++i`.
          inline: false

          # set to true to include a random string in reference titles.
          # Avoids conflicts if you're only running on part of a document
          # or using SearchLink multiple times within a document
          prefix_random: true

          # set to true to add titles to links based on the page title
          # of the search result. Can be disabled per search with `--t`,
          # or enabled with `++t`.
          include_titles: false

          # set to true to attempt to remove SEO elements from page titles,
          # such that "Regular expressions for beginners | Brett Terpstra.com"
          # becomes "Regular expressions for beginners"
          remove_seo: false

          # confirm existence (200) of generated links. Can be disabled
          # per search with `--v`, or enabled with `++v`.
          validate_links: false

          # If the link text is left empty, always insert the page title
          # E.g. [](!g Search Text)
          empty_uses_page_title: false

          # Formatting for social links, use %service%, %user%, and %url%
          # E.g. "%user% on %service%" => "ttscoff on Twitter"
          #      "%service%/%user%" => "Twitter/ttscoff"
          #      "%url%" => "twitter.com/ttscoff"
          social_template: "%service%/%user%"

          # append affiliate link info to iTunes urls, empty quotes for none
          # example:
          # itunes_affiliate: "&at=10l4tL&ct=searchlink"
          itunes_affiliate: "&at=10l4tL&ct=searchlink"

          # to create Amazon affiliate links, set amazon_partner to your amazon
          # affiliate tag
          #    amazon_partner: "bretttercom-20"
          amazon_partner: "bretttercom-20"

          # To create custom abbreviations for Google Site Searches,
          # add to (or replace) the hash below.
          # "abbreviation" => "site.url",
          # This allows you, for example to use [search term](!bt)
          # as a shortcut to search brettterpstra.com (using a site-specific
          # Google search). Keys in this list can override existing
          # search trigger abbreviations.
          #
          # If a custom search starts with "http" or "/", it becomes
          # a simple replacement. Any instance of "$term" is replaced
          # with a URL-escaped version of your search terms.
          # Use $term1, $term2, etc. to replace in sequence from
          # multiple search terms. No instances of "$term" functions
          # as a simple shortcut. "$term" followed by a "d" lowercases
          # the replacement. Use "$term1d," "$term2d" to downcase
          # sequential replacements (affected individually).
          # Long flags (e.g. --no-validate_links) can be used after
          # any url in the custom searches.
          #
          # Use $terms to slugify all search terms, turning
          # "Markdown Service Tools" into "markdown-service-tools"
          custom_site_searches:
            bt: brettterpstra.com
            btt: https://brettterpstra.com/topic/$term1d
            bts: /search/$term --no-validate_links
            md: www.macdrifter.com
            ms: macstories.net
            dd: www.leancrew.com
            spark: macsparky.com
            man: http://man.cx/$term
            dev: developer.apple.com
            nq: http://nerdquery.com/?media_only=0&query=$term&search=1&category=-1&catid=&type=and&results=50&db=0&prefix=0
            gs: http://scholar.google.com/scholar?btnI&hl=en&q=$term&btnG=&as_sdt=80006
          # Remove or comment (with #) history searches you don't want
          # performed by `!h`. You can force-enable them per search, e.g.
          # `!hsh` (Safari History only), `!hcb` (Chrome Bookmarks only),
          # etc. Multiple types can be strung together: !hshcb (Safari
          # History and Chrome bookmarks).
          history_types:
          - safari_bookmarks
          - safari_history
          # - chrome_history
          # - chrome_bookmarks
          # - firefox_bookmarks
          # - firefox_history
          # - edge_bookmarks
          # - edge_history
          # - brave_bookmarks
          # - brave_history
          # - arc_history
          # - arc_bookmarks
          # Pinboard search
          # You can find your api key here: https://pinboard.in/settings/password
          pinboard_api_key: ''
          # Generate an access token at https://app.bitly.com/settings/api/
          bitly_access_token: ''
          bitly_domain: 'bit.ly'

        ENDCONFIG

        File.open(File.expand_path('~/.searchlink'), 'w') do |f|
          f.puts default_config
        end
      end

      @cfg = YAML.load_file(File.expand_path('~/.searchlink'))

      # set to true to have an HTML comment inserted showing any errors
      @cfg['debug'] ||= false

      # set to true to get a verbose report at the end of multi-line processing
      @cfg['report'] ||= false

      @cfg['backup'] = true unless @cfg.key? 'backup'

      # set to true to force inline links
      @cfg['inline'] ||= false

      # set to true to add titles to links based on site title
      @cfg['include_titles'] ||= false

      # set to true to remove SEO elements from page titles
      @cfg['remove_seo'] ||= false

      # set to true to use page title as link text when empty
      @cfg['empty_uses_page_title'] ||= false

      # change this to set a specific country for search (default US)
      @cfg['country_code'] ||= 'US'

      # set to true to include a random string in ref titles
      # allows running SearchLink multiple times w/out conflicts
      @cfg['prefix_random'] = false unless @cfg['prefix_random']

      @cfg['social_template'] ||= '%service%/%user%'

      # append affiliate link info to iTunes urls, empty quotes for none
      # example:
      # $itunes_affiliate = "&at=10l4tL&ct=searchlink"
      @cfg['itunes_affiliate'] ||= '&at=10l4tL&ct=searchlink'

      # to create Amazon affiliate links, set amazon_partner to your amazon
      # affiliate tag
      #    amazon_partner: "bretttercom-20"
      @cfg['amazon_partner'] ||= ''

      # To create custom abbreviations for Google Site Searches,
      # add to (or replace) the hash below.
      # "abbreviation" => "site.url",
      # This allows you, for example to use [search term](!bt)
      # as a shortcut to search brettterpstra.com. Keys in this
      # hash can override existing search triggers.
      @cfg['custom_site_searches'] ||= {
        'bt' => 'brettterpstra.com',
        'imdb' => 'imdb.com'
      }

      # confirm existence of links generated from custom search replacements
      @cfg['validate_links'] ||= false

      # use notification center to show progress
      @cfg['notifications'] ||= false
      @cfg['pinboard_api_key'] ||= false

      @line_num = nil
      @match_column = nil
      @match_length = nil
    end

    def restore_prev_config
      @prev_config&.each do |k, v|
        @cfg[k] = v
        $stderr.print "\r\033[0KReset config: #{k} = #{@cfg[k]}\n" unless SILENT
      end
      @prev_config = {}
    end
  end
end
