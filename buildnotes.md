template: markdown,git,project
project: searchlink
readme: src/_README.md
download_title: SearchLink
download_url: https://github.com/ttscoff/searchlink/releases/latest/download/SearchLink.zip

# SearchLink

# Branching

I'm doing everything on main and tagging releases. If you feel like creating a feature branch, just create a branch off of main and merge it back in after testing.

Tag releases with `gh release create --title TITLE -n "NOTE"`. Run `git pull` afterward to add the tag locally. Upload zip files to the new release with `gh release upload TAG FILE.zip`. This is handled by the Finalize Deploy topic.

## Edit

Main source is in `bin/searchlink`, with the code split between files in `lib` (gem configuration). 

Before deploying, run `compile.rb` to gather all sources into a single file for use in the Services. (This is handled by the Prepare Deploy topic.)

@run(subl -p searchlink.sublime-project)

## Test

This topic will pass its arguments to the searchlink executable. To run spec tests, use `rake test`.

```run
#!/bin/bash
echo $* | bundle exec bin/searchlink
```

## Run RSpec

@run(rake spec)

## Compile Script

To run as a Service, the script needs to be compiled into a single, long script. Import statements in the source that are preceded by `#import` will be combined by the compile.rb script.

@run(./compile.rb) Compile a single script from library

## Clip Copy of Script

@include(Compile Script)
@run(cat searchlink.rb|pbcopy) Copy searchlink.rb to clipboard

## Open Automator Services

@include(Clip Copy of Script)

```run Open the SearchLink services in Automator
open -a Automator ~/Library/Services/SearchLink\ File.workflow
open -a Automator ~/Library/Services/SearchLink.workflow
```

## Create Release

```run Create release with changelog using gh
#!/usr/bin/env ruby

puts `changelog -u`

version = `rake sver`.strip

`git commit -a -m "#{version} version bump"`
`git pull`
`git push`

status = `changelog > current_changes.md; echo $?`

if status.to_i == 0
	puts `gh release create #{version} -t "v#{version}" -F current_changes.md`
	`git pull`
end

# Push a gem
`rake clobber package`
`gem push pkg/searchlink-#{version}.gem`

new_ver = `rake bump[patch]`
puts `git commit -a -m "Version bump #{new_ver}"`
```

## Upload Zip

```run Upload zip of Services
#!/usr/bin/env ruby
require 'fileutils'

version = `rake cver`.strip
zipball = "dist/SearchLink.zip"
FileUtils.mkdir_p('dist')
FileUtils.rm(zipball) if File.exist?(zipball)
puts "Creating #{zipball}"
`zip -r "#{zipball}" "SearchLink Services/"*`
puts `gh release upload #{version} #{zipball}`
```

## Prepare for Deploy

@include(open automator services)
@run(changelog -u)

## Stage Deploy

```run Clean up git
#!/bin/bash
version=$(rake sver)
git commit -a -m "Preparing for $version release"
git pull
git push
```

## Finalize Deploy

@before
1. Update Changelog
1. Open Searchlink and SearchLink File in Automator (bld auto)
2. Paste in current contents of searchlink.rb
3. File->Export and save CodeSigned workflows to /SearchLink Services
4. Git commit and push

All of this can be done with `bld prepare` and `bld stage`
@end

- Compress 3 services to SearchLink.zip
- Create a git release for X.X.X 
- Upload zip to release
- Update blog project and downloads

```run Make sure all 3 services are present
#!/usr/bin/env ruby
result = true

['SearchLink.workflow', 'SearchLink File.workflow', 'Jump to SearchLink Error.workflow'].each { |f| result = false unless File.exist?(File.join('SearchLink Services', f)) }

raise "Missing one or more Services" unless result
```

@include(Create Release)
@include(Upload Zip)
@include(Update Blog Project)
@include(Update Download)

@after
Don't forget to deploy the blog with the new readme/changelog.
@end
