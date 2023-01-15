# SearchLink

A macOS Service for Markdown writers that allows you to add hyperlinks while writing without switching to your browser.

<!--README-->
### Introduction

<!--JEKYLL{% img alignright /uploads/2012/10/SearchLink.jpg %}-->

SearchLink is a System Service for macOS which handles searching multiple sources and automatically generating Markdown links for text.

It works in a few ways:

- Run a quick search on a single selection, and have the selection replaced with the resulting url (and optional title) as a Markdown inline link, a Markdown reference, or just a plain url.
- Run a single search and have the results put on your clipboard, perfect for using from scripts and launchers (e.g. LaunchBar or Alfred).
- The "bracket" format, which allows you to just *write*, marking things to link as you go. When you're done, you can run it on the full document and --- if your queries were good --- have your links generated automatically without ever opening a browser.

This has replaced the "Auto-link web search" service in the [Markdown Service Tools](/projects/markdown-service-tools/ "Markdown Service Tools - Brett Terpstra"). The difference is that you can now mark links and specify how they should be searched for, as well as provide alternate query terms for linked text.

<!--JEKYLL
Here's a video tutorial from Aaron Dowd ([@thepodcastdude](https://twitter.com/thepodcastdude)):

{% youtube QD-u6JP83us 853 480 %}

And here some tutorial posts:

{% series_list SearchLink Tips %}
-->

### Basic search format

You can highlight any text and run SearchLink. By default, it will run a DuckDuckGo search and replace the text with a Markdown link to the first result. If you end the selected text with "!!", it will only output the url. This form is good for quick searches from LaunchBar or Alfred. If you end the search with a "^" --- which can be before or after a "!!" --- it will copy the result to the clipboard and not print anything out.

To search DuckDuckGo for a link to [MailMate](http://freron.com/) and copy it to your clipboard, you just use:

    mailmate app !!^

You can also run a basic search with one of the `!args` listed below. Start the selection or input with `!arg` (where "arg" is the search abbreviation) and all of the text after it in the selection becomes the search terms for that type.

To run a "software" search for MailMate and output only a link:

    !s mailmate!!

Running just `!s mailmate` will replace the selection with a full Markdown link.

These searches are designed for quick, on-the-fly searching.

You can also create a reference-format Markdown link by placing a colon (":") at the end of the query. That lets you write a query on a line by itself and turn it into a link you can use later while writing.

{% img aligncenter /uploads/2014/04/searchlink_referencelink.gif 899 232 %}

In single line searches, text in parenthesis or double quotes will be used as the link title (parenthesis removed during the search).

### Advanced search format

When you're writing or blogging, it's time consuming to think about linking as you go. With these formats, you can basically leave a note about what a certain phrase should be linked to and keep writing. When you're done, run SearchLink on the entire selection and all of your "noted" links will be updated.

You format text to be linked with a familiar Markdown pattern:

    [text to link](!arg "optional search text")

We'll get into `!arg` in a second. The `[text to link]` portion is just that: the text that will be visible and linked in the output. `"optional search text"`, if it exists, will be used as the search query instead of the link text. If you begin the optional search text with a '+', it will be appended to the link text for the search (only the text in square brackets will appear in the final link). If a portion of the search text is in double quotes, that portion will be used as the link text.

You can also leave the "text to link" portion empty and the title of the search result found with the "optional search text" will be inserted, e.g. `[](!g "Marked 2 app")` produces `[Marked 2 - smart tools for smart writers](http://marked2app.com/ "Marked 2 - smarter tools for smarter writers")`. 

(There's a config setting that enables replacing empty square brackets with the title. To force this, include a % sign, e.g. `[%](!s marked 2)`.)

### Available searches

SearchLink uses various API's to provide results for specific types of queries. These are denoted by an exclamation mark followed by one of the following keys:

**!arguments:**

| !search | Definition |
| -----------: | :---------------- |
|| **Software** |
| `!mas` | search Mac App Store |
| `!masd` | search Mac App Store, return seller URL |
| `!itu` | search iTunes App Store |
| `!itud` | search iTunes App Store, return seller URL |
| `!s` | software search using DuckDuckGo |
|| **General** |
| `!g` | first Google result (actually uses DuckDuckGo these days) |
| `!ddg` | first DuckDuckGo result |
| `!z` | DuckDuckGo Zero-Click result, falls back to regular DDG search |
|| **Terminology** |
| `!wiki` | Wikipedia link (Wikipedia API) |
| `!def` | Dictionary link (Wordnik) |
| `!spell` | returns the first spelling suggestion. Also works on multiple words, each spell-checked individually. |
|| **Media** |
| `!isong` | iTunes song link |
| `!iart` | iTunes artist link |
| `!ialb` | iTunes album link |
| `!ipod` | iTunes podcast link |
| `!imov` | iTunes movie link |
| `!amsong` | Apple Music song link |
| `!amsonge` | Apple Music song embed (iframe) |
| `!amart` | Apple Music artist link |
| `!amalb` | Apple Music album link |
| `!amalbe` | Apple Music album embed (iframe) |
| `!ampod` | Apple Music podcast link |
| `!lsong` | Last.fm song link |
| `!lart` | Last.fm artist link |
| `!tmdb` | The Movie Database link (movie, tv show, or actor) |
| `!tmdba` | The Movie Database actor link |
| `!tmdbm` | The Movie Database movie link |
| `!tmdbt` | The Movie Database tv show link |
|| **Amazon** |
| `!a` | Amazon product search in all categories |
|| **Site search** |
| `!example.com` | any url (no protocol) becomes a site-specific search |
|| **History and Bookmarks** |
| `!pb` | Search your Pinboard bookmarks\*. See [Searching Pinboard](#searching-pinboard) below |  
| `!h` | Search configured Chrome, Firefox, and Safari History and Bookmarks. See [Searching Browser Data](#searching-browser-history-and-bookmarks) below. |
|| **Twitter, Instagram, LinkedIn, Mastodon, and Facebook usernames** |
| `!@t` | Link text as Twitter username |
| `!@i` | Link text as Instagram username |
| `!@f` | Link text as Facebook username |
| `!@l` | Link text as LinkedIn username |
| `!@m` | Link text as Mastodon username |

Any search that has a link title but no search defined will automatically default to DuckDuckGo search for the title text. For example, `[Animal Farm]()` within a block of text will search DuckDuckGo for "Animal Farm" and create the link, and running SearchLink with only the words "Animal Farm" selected will do the same.

If no `[](!xxx)` syntax is found in the text you run SearchLink on, it will default to a DuckDuckGo search for the entire selected text, replicating the behavior of the previous "Auto-link web search" command in the [Markdown Service Tools](https://brettterpstra.com/projects/markdown-service-tools/).

### Modifiers

The following symbols can be added to the end of a single-line search to affect the output. They can be used in combination:

* `!!` will only return the URL without any link formatting
* `^` will output the result to the clipboard and leave input text in place
* `~` will check your clipboard for a link and wrap the selected text instead of running a search. If used with the `:` syntax, it will create an instant reference definition for the url in the clipboard
* `:` will return a reference link definition (`[text]: url`). This works with bracket syntax as well.
    - if the resulting link already exists, any defined reference id will be replaced with the existing definition's id
    - if a future search results in an identical link, it will re-use the id of the generated reference definition
    - the reference definition will be moved to the end of the selection on multi-line searches
* Using `^` at the beginning of the parenthetical portion of the bracket syntax will create a footnote instead of running a search. (e.g. `[1](^footnote text)`).

### Reporting

When running SearchLink on a full document, you can configure it to provide a report of results at the end of the document in HTML comments. It can be configured to show only errors, only successes, or both.

There's a Service included called "Jump to SearchLink Error" which, when run while a report/error line is selected, will jump the cursor to the location in the document where the error occurred or the change was made.


### Configuration {#searchlinkconfig}

Default values can be specified in a `.searchlink` file in your home directory. This file is automatically created when you run SearchLink if it doesn't already exist.

If you know your way around Terminal at all it should be easy enough to edit this file. If you're not a command line user, you'll want to do this from Finder:

1. Open your user's Home folder in Finder using **Go->Home** or just pressing <kbd>??????H</kbd> (Shift-Command-H)
2. Show invisible files by pressing <kbd>??????.</kbd> (Shift-Command-Period)
3. Locate `.searchlink` in the file listing (it will be visible but greyed out)
4. Right click on `.searchlink` and choose **Open In...**
5. Select TextEdit (or your preferred text editor)

Below is the full set of options, along with comments describing their effect:

```yaml
# set to true to have an HTML comment included detailing any errors
debug: true
# set to true to have an HTML comment included reporting results
report: true

# use Notification Center to display progress
notifications: false

# when running on a file, back up original to *.bak
backup: true

# change this to set a specific country for search (default US)
country_code: US

# set to true to force inline Markdown links
inline: false

# set to true to include a random string in reference titles.
# Avoids conflicts if you're only running on part of a document
# or using SearchLink multiple times within a document
prefix_random: true

# set to true to add titles to links based on the page title
# of the search result
include_titles: false

# If the link text is left empty, always insert the page title
# E.g. [](!g Search Text)
empty_uses_page_title: true

# confirm existence (200) of generated links. Can be disabled
# per search with `--v`, or enabled with `++v`.
validate_links: true

# Formatting for social links, use %service%, %user%, and %url%
# E.g. "%user% on %service%" => "ttscoff on Twitter"
#      "%service%/%user%" => "Twitter/ttscoff"
#      "%url%" => "twitter.com/ttscoff"
social_template: "%service%/%user%"

# append affiliate link info to iTunes urls, empty quotes for none
# example:
# itunes_affiliate = "&at=10l4tL&ct=searchlink"
itunes_affiliate: "&at=10l4tL&ct=searchlink"

# to create Amazon affiliate links, set amazon_partner to:
# [tag, camp, creative]
# Use the amazon link tool to create any affiliate link and examine
# to find the needed parts. Set to false to return regular amazon links
# example:
#    amazon_partner: ["bretttercom-20","1789","390957"]
amazon_partner: ["brettterpstra-20", "1789", "9325"]

# To create custom abbreviations for DuckDuckGo Site Searches,
# add to (or replace) the hash below.
# "abbreviation" => "site.url",
# This allows you, for example to use [search term](!bt)
# as a shortcut to search brettterpstra.com (using a site-specific
# DuckDuckGo search). Keys in this list can override existing
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
  btt: http://brettterpstra.com/$term1d/$term2d
  bts: /search/$term --no-validate_links
  md: www.macdrifter.com
  tuaw: www.tuaw.com
  ms: macstories.net
  dd: www.leancrew.com
  spark: macsparky.com
  man: http://man.cx/$term
  dev: developer.apple.com
  dl: http://marked2app.com/download/Marked.zip

# Remove or comment (with #) history searches you don't want
# performed by `!h`. You can force-enable them per search, e.g.
# `!hsh` (Safari History only), `!hcb` (Chrome Bookmarks only),
# etc. Multiple types can be strung together: !hshcb (Safari
# History and Chrome bookmarks).
history_types:
- chrome_history
- chrome_bookmarks
- safari_bookmarks
- safari_history
- firefox_bookmarks
- firefox_history
# You can find your api key here: https://pinboard.in/settings/password
pinboard_api_key: ''
```

### Custom Searches

These notes can be found in the configuration file comments, but they're worth mentioning separately. SearchLink not only searches all the major engines, but also allows you to extend its options to search anything you need.

Add Custom Searches to the `custom_site_searches` section of the configuration file. These can serve as either replacement shortcuts or site searches, can handle and manipulate multiple terms individually, and can accept flags (see below) on a per-search basis.

If a custom search starts with "http" or "/", it becomes a simple replacement. Any instance of `$term` is replaced with a URL-escaped version of your search terms. Use `$term1`, `$term2`, etc. to replace in sequence from multiple search terms. If there are no instances of `$term` in the value, it functions as a simple shortcut. `$term` followed by a "d" lowercases the replacement. Use `$term1d`, `$term2d`, etc. to downcase sequential replacements (affected individually). Long flags (e.g. `--no-validate_links`) can be used after any url in the custom searches.

Use `$terms` to "slugify" all terms, turning "Markdown Service Tools" into `markdown-service-tools` in the replacement.

**Examples:**

    custom_site_searches:
      bt: brettterpstra.com
      btt: http://brettterpstra.com/$term1d/$term2d
      bts: /search/$term --no-validate_links
      md: www.macdrifter.com
      tuaw: www.tuaw.com
      ms: macstories.net
      dd: www.leancrew.com
      spark: macsparky.com
      man: http://man.cx/$term
      dev: developer.apple.com
      dl: http://marked2app.com/download/Marked.zip


### Flags and switches

You can override defaults for an entire document by using MultiMarkdown metadata at the top of the document. The following headers can be set in MMD:

* debug
* country\_code
* inline
* prefix\_random
* include\_titles
* validate\_links

These headers are set at the very top of the document (or selection) in the format `key: value`. For example:

    debug: true
    inline: true

Those two lines will turn on debugging and force inline links, regardless of the settings in `~/.searchlink`.

Headers set in MMD metadata are global for the document (unless overridden by a flag) and not removed from the output

You can also modify settings per search with `--flags`. Just include a flag within the parenthesis or at the end of a single line search. Use `--no-[flag]` to turn an option off. The following can be switched per link with `--(no-)key`:

* inline
* include\_titles,
* validate\_links

Values changed by flags are restored after processing each link.

Flags can also be used after custom search engine definitions in the configuration file. Flags in definitions are overridden by flags in the input.
You can use this for applications such as never validating links of a certain type:

    # In ~/.searchlink:
    custom_site_searches
        # lowercases the query and never validates
        tag: http://brettterpstra.com/topic/$termd/ --no-validate_links

    $ !btt markdown

    => [markdown](http://brettterpstra.com/topic/markdown/)

Shortcuts are available for some flags.
    - debug = `d`
    - inline = `i`
    - include\_titles = `t`
    - validate\_links = `v`

Enable options with `++[options]`, disable with `--[options]`. Multiple shorcuts can be grouped together, and both `++` and `--` can be used in the same link. Only the first appearance of a flag is used, repeats are ignored:

    # do a DuckDuckGo search for the link text
    # additional (+) search terms appended to query
    # no link validation (--v)
    # create an inline link with a title (++it)

    [Martha Stewart](!g --v ++it)
    => [Martha Stewart](http://www.marthastewart.com/ "Martha Stewart - Recipes, DIY, Home Decor &amp; Crafts")

### Searching Pinboard

If you use the [Pinboard](https://pinboard.in) bookmarking service, you can easily grab links you've already bookmarked using the `!pb` search type. This makes it easy to gather known links yourself, as you find them, and then easily use them in your writing.

To use this, you need your Pinboard API key, which you can find [on your settings page](https://pinboard.in/settings/password). Add it to `~/.searchlink` like:

    pinboard_api_key: 'ttscoff:XXXXXXXXXXXXXXXX'

To query your pinboard bookmarks, just use `!pb QUERY_STRING`. Query string can be any number of words, the bookmark with the most matching words will be selected.

The title and description of your links will be scored against your search terms, and the most recent bookmark with the highest score will be returned. The order of words in the query doesn't matter, punctuation and casing is ignored. If a bookmark contains _most_ of the words in the query, it will be returned. Exact string matches are scored highest, and matches in title are scored higher than matches in description.

    [%](!pb ruby facets swell) => [rubyworks/facets: Ruby Facets](https://github.com/rubyworks/facets)

You can force the Pinboard search to do an exact string match (ignoring capitalization and punctuation) within the title and description by beginning the search string with a double single quote:

    [%](!pb ''ruby facets)

Because bookmarks are sorted by date, you can easily get a recently-added bookmark with a single word, as long as it's the most recent bookmark to contain that word. So if you knew you'd just saved a page on "strftime formatting," you could simply run `!pb strftime` to grab that link and title.

### Searching Browser History and Bookmarks

The `!h` search will comb through your browser history and bookmarks for a matching title. Supported browsers are Chrome, Safari, Firefox, Edge, and Brave.

You can define which browsers/types are searched in the config:

```yaml
history_types:
- chrome_history
- chrome_bookmarks
- safari_bookmarks
- safari_history
- firefox_bookmarks
- firefox_history
- edge_bookmarks
- edge_history
- brave_bookmarks
- brave_history
```

Whichever searches appear in that list in config will all be searched when running a `!h` search. Remove any you never want to search (i.e. browsers you don't use).

You can specify exactly what to search as part of the command by following it with a letter for a specific browser (e.g. 's' for Safari) and an 'h' (history), 'b' (bookmarks), or both. For example, to search just Chrome bookmarks, I would use `!hcb oracle code repositories`. To search both Firefox history and bookmarks, I would use `!hfhb`.

### Examples

Here's a list of sample links.

    * A search for specified text: [Marked](!g "Marked mac app").
    * A simple software search for [Fantastical](!s).
    * A simple google search [neat neat neat](!g)
    * A Last.fm track search [neat neat neat](!lsong "The Damned Neat Neat Neat") (with specified search terms)
    * Mac app store search: [Marked on the MAS](!mas "Marked")
    * Mac App Store search [Marked direct](!masd "Marked") with direct dev site link.
    * iTunes app search: [Boost 2](!itu)
    * iTunes search, direct dev site link: [Boost direct](!itud "Boost 2")
    * This search: [](!mas "Omnifocus") will have its link text filled in with the title of the first result.
    * This is a wikipedia entry for [Sid Vicious](!wiki)
    * This will put the definition of [ambiguous](!def) in the title field of a link to the dictionary entry.
    * iTunes Artist search: [BRMC](!iart "Black Rebel Motorcycle Club")
    * Site specific search: [Keybindings](!brettterpstra.com "Keybinding Madness")
    * [ttscoff](!@t) and [ttscoff](!@f)

When SearchLink is run on the above block of text, it outputs:

    * A search for specified text: [Marked][1].
    * A simple software search for [Fantastical][2].
    * A simple google search [neat neat neat][3]
    * A Last.fm track search [neat neat neat][4] (with specified search terms)
    * Mac app store search: [Marked on the MAS][5]
    * Mac App Store search [Marked direct][1] with direct dev site link.
    * iTunes app search: [Boost 2][6]
    * iTunes search, direct dev site link: [Boost direct][6]
    * This search: [Omnifocus][7] will have its link text filled in with the title of the first result.
    * This is a wikipedia entry for [Sid Vicious][8]
    * This will put the definition of [ambiguous][9] in the title field of a link to the dictionary entry.
    * iTunes Artist search: [BRMC][10]
    * Site specific search: [Keybindings][11]
    * [twitter.com/ttscoff][12] and [facebook.com/ttscoff][13]

    [1]: http://markedapp.com/ "Marked - smart tools for smart writers"
    [2]: http://flexibits.com/ "Flexibits | Fantastical | Meet your Mac&#39;s new calendar."
    [3]: http://www.youtube.com/watch?v=4JeDxJkAorU "The Damned Neat Neat Neat - YouTube"
    [4]: http://www.last.fm/music/The+Damned/_/Neat+Neat+Neat "Neat Neat Neat by The Damned"
    [5]: https://itunes.apple.com/us/app/marked/id448925439?mt=12&uo=4&partnerId=30&siteID=vRL5rYo4h5A "Marked"
    [6]: https://itunes.apple.com/us/app/boost-2/id333191476?mt=8&uo=4&partnerId=30&siteID=vRL5rYo4h5A "Boost 2"
    [7]: https://itunes.apple.com/us/app/omnifocus-2/id867299399?mt=12&uo=4&at=10l4tL&ct=blog "OmniFocus"
    [8]: http://en.wikipedia.org/wiki/Sid_Vicious "Sid Vicious"
    [9]: http://dictionary.reference.com/browse/ambiguous "open to or having several possible meanings or interpretations; equivocal: an   ambiguous answer. 2. Linguistics. (of an expression) exhibiting constructional ..."
    [10]: https://itunes.apple.com/us/artist/black-rebel-motorcycle-club/id624658?uo=4 "Black Rebel Motorcycle Club"
    [11]: http://brettterpstra.com/keybinding-madness/ "KeyBinding madness - Brett Terpstra"
    [12]: https://twitter.com/ttscoff
    [13]: https://www.facebook.com/ttscoff

(See the [rendered output here](https://gist.github.com/3900130))

You can also fill empty links using DuckDuckGo searches. If a search link doesn't have text but has a search query, the page title of the result is used for the anchored text. If it doesn't have a link but has text, the text is used for the query and the link is inserted.

Page titles are only inserted in empty text if `empty_uses_page_title: true` is in the config file. If the text of a link is just a percent symbol (`%`), it will force the use of the page title regardless of this setting, allowing you to selectively use page titles.

    * Default to DuckDuckGo: [brett terpstra]()
        => [brett terpstra](http://brettterpstra.com/)
    * Default to DuckDuckGo: []("brett terpstra")
        => [Brett Terpstra](http://brettterpstra.com/)
    * Search DuckDuckGo, preserving link text: [me](!g brett terpstra)
        => [me](http://brettterpstra.com/)
    * Macstories search for brett: [](!ms "brett terpstra")
        => [MacStories Interviews: Brett Terpstra - MacStories](http://www.macstories.net/stories/macstories-interviews-brett-terpstra/)
    * TUAW search for brett, using page title: [%](!tuaw "brett terpstra")
        => [Brett Terpstra - TUAW.com](http://www.tuaw.com/editor/brett-terpstra/)

When running it on a full document, you can rest assured that it won't touch links that area already complete or that weren't intended to be searches:

* Complete links are preserved:
    * `[Projects](http://brettterpstra.com/projects/cheaters)`
    * `[Cheaters](/projects/cheaters)`
    * `[Cheaters](projects/cheaters/index.html)`
* Searches that return no results leave the original markup intact

It will ignore any malformed searches, too:

* Empty sets do nothing: `[]()`
* Empty search text does nothing: `[](!g)`

### Single-line searches

These searches are meant to be selected as a single line and passed to SearchLink.

- Defaults to DuckDuckGo

   Star Trek TNG The Measure of a Man
- Assumes a site-specific search

    !imdb.com Filth movie ++t
- Custom search replacement, force validate and debug (will fail)

    !btt markdown barf ++dv
- Mac App Store search, link only

    !mas AmpKit!!
- iTunes artist search, Markdown reference link

    !iart the cramps:

Note that it uses reference style linking by default. Duplicate results are culled and their marker repeated as needed, and it will begin numbering after the highest numbered reference located in the passed text. If you run it with only one `(!arg)` link in the selection, it will automatically switch to inline linking. See the [configuration section](#searchlinkconfig) if you want to always force inline linking.

#### Converting Social handles

As a shortcut to creating links to social media services, you can turn a username into a full link in a single line search. Start the username with a letter indicating the service, followed by an `@`, and the rest will be figured out. If there's no preceding letter, the conversion defaults to Twitter or Mastodon, depending on whether the handle has an @ in the middle or not.

    @ttscoff => [twitter.com/ttscoff](https://twitter.com/ttscoff)
    @ttscoff@nojack.easydns.ca => [Mastodon/ttscoff@nojack.easydns.ca](https://nojack.easydns.ca/@ttscoff)
    i@ttscoff => [instagram.com/ttscoff](https://www.instagram.com/ttscoff/)
    f@ttscoff => [facebook.com/ttscoff](https://www.facebook.com/ttscoff)
    l@BrettTerpstra => [linkedin.com/in/BrettTerpstra](https://www.linkedin.com/in/BrettTerpstra/)

You can format the way the text of the link appears using the `social_template` setting in `~/.searchlink`. This is a template string using the placeholders `%user%`, `%url%`, and `%service%`.

    # Formatting for social links, use %service%, %user%, and %url%
    # E.g. "%user% on %service%" => "ttscoff on Twitter"
    #      "%service%/%user%" => "Twitter/ttscoff"
    #      "%url%" => "twitter.com/ttscoff"
    social_template: "%service%/%user%"

### Installation

Download the zip file [at the end of this post](#dl) and double click it to extract the `.workflow` files. Place them in `HOME/Library/Services` (or just double click them and it will ask if you'd like to install each one). They should become available immediately.

In order to avoid editing the Service directly (and having your configuration overwritten with every update), you can create a `.searchlink` file in your home directory. See [Configuration](#searchlinkconfig)

You can assign a keyboard shortcut as well. See [the howto](http://brettterpstra.com/howtos/install-an-os-x-system-service/) for more information.

In order to use the spellchecking feature, you need to have `aspell` installed. If you have homebrew on your system, you can just use `brew install aspell`, or go to the [aspell homepage](http://aspell.net/) to download a package.

You can get more faster and more accurate page titles if you have [Gather](https://brettterpstra.com/projects/gather-cli) installed. Installing via the downloadable PKG installer is the easiest method.

### Usage

To run on a full document or block selection, select some text containing `[link](!arg)` formatted searches, right/control click on the selection and find the "Services" menu at the bottom of the contextual menu that pops up (also available under the application menu in the menu bar). Under Services, select SearchLink and run it. It may take a while depending on how many links are in the text. Any links that return errors or no results are left as is.

For a single line search, just select the text to search with any `!args` preceding it and optional `--flags` and modifiers after it, and then run the SearchLink Service.

You can use the SearchLink File Service by selecting one or more files in the Finder and running it. By default, backups will be created and the files will be modified in place.

<!--JEKYLL{% img /uploads/2012/10/searchlinkservicejpg.jpg 664 111 "SearchLink Service usage" %}-->

If you're a LaunchBar or Alfred user, you can also use the Service directly on any input text, or [create an Action](#bonus-for-launch-bar-users) to simplify searching from the launcher.

<!--END README-->

{% donate %}

### Download ### {#dl}

There will likely be updates to this as I solve more problems, so keep an eye on this page for new versions. The current source code is [available on GitHub](https://github.com/ttscoff/searchlink).

{% download 70 %}

### Bonus for LaunchBar users

With the AppleScript below saved to `~/Library/Application Support/LaunchBar/Actions/Instant Search.scpt`, you can use SearchLink as a launcher for the web. Load the action in LaunchBar, type Space and enter a SearchLink simple query (just text with optional !arg at the beginning). When you hit Enter it will grab the first link and load it in the Open URL action. Enter again will open it in your browser, ???C will copy it to your clipboard.

Note that you don't need the normal "!!" at the end of the search string to specify that SearchLink should just return the URL, that's included in the script.

{% gist 9067625 %}

### Changelog

{% changelog searchlink.md %}
