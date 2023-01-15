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

This has replaced the "Auto-link web search" service in the [Markdown Service Tools](https://brettterpstra.com/projects/markdown-service-tools/ "Markdown Service Tools - Brett Terpstra"). The difference is that you can now mark links and specify how they should be searched for, as well as provide alternate query terms for linked text.

Here's a video tutorial from Aaron Dowd ([@thepodcastdude](https://twitter.com/thepodcastdude)):

<!--JEKYLL
{% youtube QD-u6JP83us 853 480 %}

And here some tutorial posts:

{% series_list SearchLink Tips %}
-->

<!--GITHUB-->
<iframe width="560" height="315" src="https://www.youtube.com/embed/QD-u6JP83us" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
<!--END GITHUB-->

### Documentation

<!--GITHUB-->
The documentation has [moved to a wiki](https://github.com/ttscoff/searchlink/wiki).
<!--END GITHUB-->
<!--JEKYLL[Go to the Docs Wiki](https://github.com/ttscoff/searchlink/wiki){:.btn}-->

### Download

There will likely be updates to this as I solve more problems, so keep an eye on this page for new versions. The current source code is [available on GitHub](https://github.com/ttscoff/searchlink).

<!--JEKYLL{% download 70 %}-->

<!--JEKYLL[Latest release on GitHub](https://github.com/ttscoff/searchlink/releases/latest/){:.btn.btn--alt}-->

<!--GITHUB-->
Download the SearchLinkX.X.X.zip file from the [latest release](https://github.com/ttscoff/searchlink/releases/latest/).
<!--END GITHUB-->

### Bonus for LaunchBar users

With the AppleScript below saved to `~/Library/Application Support/LaunchBar/Actions/Instant Search.scpt`, you can use SearchLink as a launcher for the web. Load the action in LaunchBar, type Space and enter a SearchLink simple query (just text with optional !arg at the beginning). When you hit Enter it will grab the first link and load it in the Open URL action. Enter again will open it in your browser, ???C will copy it to your clipboard.

Note that you don't need the normal "!!" at the end of the search string to specify that SearchLink should just return the URL, that's included in the script.

<!--JEKYLL{% gist 9067625 %}-->
<!--GITHUB-->
[View the Script](https://gist.github.com/ttscoff/9067625)
<!--END GITHUB-->

<!--END README-->

### Changelog

{% changelog searchlink.md %}
