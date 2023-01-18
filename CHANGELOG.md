### 2.3.27

2023-01-18 08:37

#### NEW

- Set `remove_seo: true` in config to have page titles parsed and cleaned up, removing things like site name and url

#### FIXED

- Bad GitHub token, and silent failure when authentication fails

### 2.3.25

2023-01-18 08:35

#### NEW

- Set `remove_seo: true` in config to have page titles parsed and cleaned up, removing things like site name and url

#### FIXED

- Bad GitHub token, and silent failure when authentication fails

### 2.3.24

2023-01-18 07:56

#### IMPROVED

- Authenticate GitHub update checks to avoid rate limit

### 2.3.23

2023-01-17 11:35

#### FIXED

- When returning a file from Spotlight, url encode spaces so the link works in Markdown previews

### 2.3.22

2023-01-17 09:55

#### FIXED

- Don't unencode URLs from DDG searches, leave spaces and other characters properly encoded

### 2.3.21

2023-01-17 08:49

#### NEW

- `!bl` will shorten a link or search result using Bit.ly. Requires access token in config.

#### IMPROVED

- Better scoring for matching Safari bookmarks

### 2.3.20

2023-01-17 06:30

#### NEW

- `!file SPOTLIGHT_QUERY` will search for a local file and output a `file://` link with the filename as title

### 2.3.19

2023-01-17 06:29

#### NEW

- `!file SPOTLIGHT_QUERY` will search for a local file and output a `file://` link with the filename as title

### 2.3.18

2023-01-16 16:43

#### NEW

- Run on "version" to get the current SearchLink version
- Run SearchLink on the word "update" or "upgrade" to automatically install the latest version (if needed)
- Check for newer versions when running version commands

#### IMPROVED

- Run a quick version check every time and notify of updates available
- Remove extra spaces from titles

#### FIXED

- Plist library version overriding SeachLink version constant
- Overly broad regex for matching !z search types

### 2.3.17

2023-01-16 16:42

#### NEW

- Run on "version" to get the current SearchLink version
- Run SearchLink on the word "update" or "upgrade" to automatically install the latest version (if needed)
- Check for newer versions when running version commands

#### IMPROVED

- Run a quick version check every time and notify of updates available
- Remove extra spaces from titles

#### FIXED

- Plist library version overriding SeachLink version constant
- Overly broad regex for matching !z search types

### 2.3.16

2023-01-16 08:22

#### FIXED

- Zip download incomplete

### 2.3.15

2023-01-16 08:21

#### FIXED

- Zip download incomplete

### 2.3.14

2023-01-16 07:27

#### IMPROVED

- You can now pass a direct YouTube link (full or shortened) to !yte to convert to embed

### 2.3.13

2023-01-16 06:45

#### NEW

- Pass a tweet url to `!te` to create a Twitter embed

### 2.3.12

2023-01-15 16:52

#### NEW

- Use `!yte SEARCH` to create a YouTube embed iframe

#### IMPROVED

- Point help links to wiki, add wiki/docs command

### 2.3.10

2023-01-15 13:23

#### NEW

- Add Arc history and bookmark search

#### IMPROVED

- De-slugify reference titles when pulled from URL path, remove extensions
- Fallback title when gather fails to get a page title

#### FIXED

- Method misspelling for brave and edge bookmark search
- Creating reference title when URL has no path

### 2.3.9

2023-01-15 10:47

#### IMPROVED

- Allow space before per-document meta keys to allow nesting in YAML headers
- Refine software (!s) search. Ignore apple.com links, don't include "mac" in search terms

### 2.3.8

2023-01-15 07:27

#### NEW

- Add DuckDuckGo Zero Click search
- Add Firefox history and bookmark search
- Add Edge and Brave history and bookmark search
- Run SearchLink on a single fully-qualified URL to turn it into a Markdown link with the page title as linked text
- Run SearchLink on a url ending in : to turn it into a reference link with title generated from hostname and/or url path
- Add !yt YouTube search

#### IMPROVED

- Testing deploy automation

#### FIXED

- Fix Pinboard caching
- Fix Safari history and bookmark search

### 2.2.30

- Mastodon profile link conversion
- Pinboard query/matching improvements

### 2.2.29

- Fall back to including extended description search if Pinboard title/tags search has no results

### 2.2.28

- Add The Movie Database searching

### 2.2.27

- Fix for DuckDuckGo returning gzipped data

### 2.2.26

- Fix embed urls for iTunes searches
- Allow aspell to be discovered on M1 Macs running homebrew

### 2.2.25

- Code refactoring
- Fix missing !lsong search
- Fix for handling empty search types, e.g. `[brett terpstra]()`

### 2.2.24

- throttle rapid requests when there are more than 5 searches
- handle nil result error

### 2.2.22

- Add `s` modifier to custom search replacements to slugify all search terms

### 2.2.21

- Add !hook search for searching Hook.app bookmarks
- Code cleanup

### 2.2.20

- Fix for space encoding in returned links

### 2.2.19

- Remove old Bing references
- Fix for social linking

### 2.2.17

- Fix for DuckDuckGo server changes

### 2.2.16

- More handling for social handles (Instagram, LinkedIn)
- Templating for social handle output

### 2.2.15

- Hotfix for search results returning raw DuckDuckGo links

### 2.2.14

- Skip SEO crud removal from titles until the script is more reliable

### 2.2.13

- Restore functionality allowing empty link text to be replaced with page title
- Config option `empty_uses_page_title:`
- If link text is '%', force using page title (`[%](!g SearhLink)`)

### 2.2.12

- Fix for changes in DuckDuckGo

### 2.2.11

- Add advanced option to Jump To SearchLink Error service to allow only jumping to line, not character position or selection. (significantly faster in most cases)
- Update Apple Music embed code for responsive embed
- Fix output when running an Apple Music embed search using naked syntax

### 2.2.10

- Avoid running a search when parens do not contain a bang search, e.g. `[this search](should not run)`
- Count `#fragment` links as urls and don't run search


### 2.2.9

- Restored "Jump to SearchLink Error" Service in download

### 2.2.8

- Skipped a few increments in version numbering. Feature, not bug
- !imov search for iTunes store movie links
- Added `aspell` feature for !spell searches
- Switched `!def` (definition) searches using Wordnik
- Pinboard bookmark search

### 2.2.4

- Wikipedia API was erroring out on Sierra due to Ruby 2.0 SSL handling, replaced with a curl/scrape hack

### 2.2.3

- Replaced Bing search with DuckDuckGo, as Bing has now deprecated their search api as well
- Updated Amazon affiliate linking format
- Apple Music search and affiliate linking
- Running a single-line search on just an @username turns it into a twitter link
- Convert to a Facebook username with
    - Single line: `!@fb username`
    - Link format: `[username](!@fb)`

### 2.2.2

- Fix for wiki searches
- Select just the word "help" for a list of available searches (and custom searches)

### 2.2.0

- Bing search fallback due to deprecated ([4 years ago](http://googlecode.blogspot.com/2010/11/introducing-google-apis-console-and-our.html)) Google APIs potentially being shut down soon
    - Can be forced with `!b`

#### Simpler syntax and new syntax options

* quotes no longer required around additional search terms
* if search terms in parenthesis start with a "+", they're appended to the link text for the search, otherwise they replace it
* A tilde (~) at the end of a single-string search with no bracket syntax checks the clipboard for a url and wraps the selected text with it if found
    - can be used with the `:` syntax at the end to create a reference with the selected text as the title
    - ignores and strips `!!` (link only) and `^` syntax

            # with "http://www.tuaw.com/tag/howto/" in the clipboard

            TUAW how-to~
            => [TUAW how-to](http://www.tuaw.com/tag/howto/)

            TUAW how-to:~ (or "TUAW how-to~:")
            => [TUAW how-to]: http://www.tuaw.com/tag/howto/

- !example.com searches become site-specific web searches
- for single-line searches, text in parenthesis is searched (as additional search terms) but not included in the link text
- in single line searches without `[]()` format, text surrounded in quotes becomes the link text
    - `!g "Six Barrel Shotgun" black rebel` is the same as `!g Six Barrel Shotgun (black rebel)`
- !spell search replaces selection with most relevant spelling correction
    - works on entire blocks of text
- you can use a colon in a bracketed search and if it's alone on a line it will create a reference link definition
    - if an identical link results in future searches, it will re-use the id of the generated reference definition
    - if the resulting link already exists, any defined reference id will be replaced with the existing definition's id
    - the reference definition will be moved to the end of the document
- create footnotes with `[id](^footnote text)`
    - if id isn't specified, one is generated
    - footnotes are collected at the end and added with line breaks surrounding
- `!h` for searching your own web history
    - configure search types in ~/.searchlink

                history_types:
                - chrome_history
                - chrome_bookmarks
                - <del>safari_bookmarks</del> (currently broken)
                - <del>safari_history</del> (currently broken)
    - use `!h[sc][hb]` to configure on the fly
        - **!hsb** only searches (s)afari (b)ookmarks
        - **!hsbh** searches safari bookmarks and history
        - **!chsb** searches chrome history and safari bookmarks
        - **!h** searches all configured types from ~/.searchlink

#### New configuration options

- ~/.searchlink
    - config option to validate links (validate_links)
    - custom search definitions with a value starting with http or / and including $term in the string will simply have the value returned with the $term replaced with the input
        - `$termd` lowercases the text in the replacement string
        - More than one `$term` can be used by adding numbers after them
            - `$term1`, `$term2`
            - the search terms given are separated by a space
            - if there are more terms than tokens, the additional terms are appended to the last token
            - `$term1d` works for lowercasing
            - replacements are URL encoded
    - `report` option outputs verbose info on multi-line searches
- set configuration options with MMD metadata (per document) or flags (per link)
    - The following headers can be set in MMD: debug, country_code, inline, prefix_random, include_titles, validate_links
        - headers set at the top of the document
        - `key: value`
        - e.g. `debug: true`
        - Headers set in MMD metadata are global (unless overridden by a flag) and not removed from the output
    - The following can be switched per link with `--(no-)key`: inline,  include_titles, validate_links
        - flags are removed from the search and the output
        - values changed by flags are restored after processing each link
    - flags can be used in custom search engine definitions
        - flags in definitions are overridden by flags in the input
        - use this for applications such as never validating links of a certain type:

                # In ~/.searchlink:
                custom_site_searches
                    # lowercases the query and never validates
                    tag: http://brettterpstra.com/topic/$termd/ --no-validate_links

                $ !btt markdown

                => [markdown](http://brettterpstra.com/topic/markdown/)

    - Shortcuts are available for some flags.
        - debug = `d`, inline = `i`, include_titles = `t` , and validate_links = `v`
        - Enable options with `++[options]`, disable with `--[options]`.
        - Multiple options can be grouped together
        - both `++` and `--` can be used in the same link
        - only the first appearance of a flag is used, repeats are ignored
        - example:

                # do a google search for the link text
                # additional (+) search terms appended to query
                # no link validation (--v)
                # create an inline link with a title (++it)
                [Martha Stewart](!g --v ++it)

                => [Martha Stewart](http://www.marthastewart.com/ "Martha Stewart - Recipes, DIY, Home Decor &amp; Crafts")

#### Output formatting improvements

- link format only forces inline if a single line (no newlines) is selected
- groups new reference definitions with any existing definitions at end of selection to keep full-document selections looking tidy
- detects existing random prefix and continues pattern for easier search and replace
- duplicate urls properly re-use existing reference titles
- links in code blocks (indented or fenced) are ignored
- reports and errors are removed and replaced when running on a full document
- Jump to SearchLink Error service accepts a highlighted error line and jumps to its position in the document, highlighting the offending match

#### CLI improvements

- can run on a file if path(s) are passed as an argument (SearchLink File service)
- set `SL_SILENT=false` on the command line for verbose output
- `-debug` flag to output html comment at end of selection showing any errors
    - at end of line for single line searches
    - block format for multi-line searches
- `-version`
- `-help`
- `-stdout` outputs to STDOUT when using on files as CLI
    - default is to overwrite the file, `-stdout` cancels this out
- `-no-backup`
    - default is to create a \*.bak file when overwriting

### 2.1

- copy config options to `~/.searchlink` to preserve across upgrades
    - Config file is created on first run if it doesn't exist
- allows `[aawerg]()` for google search
- allows custom site search definitions
- allows `[](search terms)` (inserts title as link text)
- allows `[me](brett terpstra)` as google search
- better cleaning of titles
