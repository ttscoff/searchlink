require 'rake/clean'

# desc 'Update Services'
# task :update_services do
#   new_contents = IO.read('searchlink.rb')
#   services = ['SearchLink', 'SearchLink File']
#   services.each do |file|
#     wflow = "/Users/ttscoff/Library/Services/#{file}.workflow/Contents/document.wflow"
#     $stderr.puts "Updating #{wflow}"
#     contents = IO.read(wflow)
#     contents.sub!(%r{(<key>COMMAND_STRING</key>.*?<string>).*?(\n</string>)}m, "\\1#{new_contents.strip}\\2")
#     puts contents
#     File.open(wflow, 'w') do |f|
#       f.puts contents
#     end
#   end
#   $stderr.puts "Services updated: #{services.join(", ")}"
# end

desc 'Development version check'
task :ver do
  gver = `git ver`
  cver = IO.read(File.join(File.dirname(__FILE__), 'CHANGELOG.md')).match(/^#+ (\d+\.\d+\.\d+(\w+)?)/)[1]
  res = `grep VERSION searchlink.rb`
  version = res.match(/VERSION *= *['"](\d+\.\d+\.\d+(\w+)?)/)[1]
  puts "git tag: #{gver}"
  puts "version.rb: #{version}"
  puts "changelog: #{cver}"
end

desc 'Get Script Version'
task :sver do
  res = `grep VERSION searchlink.rb`
  version = res.match(/VERSION *= *['"](\d+\.\d+\.\d+(\w+)?)/)[1]
  print version
end

desc 'Changelog version check'
task :cver do
  puts IO.read(File.join(File.dirname(__FILE__), 'CHANGELOG.md')).match(/^#+ (\d+\.\d+\.\d+(\w+)?)/)[1]
end

desc 'Bump incremental version number'
task :bump, :type do |_, args|
  args.with_defaults(type: 'inc')
  version_file = 'lib/version.rb'
  content = IO.read(version_file)
  content.sub!(/VERSION = '(?<major>\d+)\.(?<minor>\d+)\.(?<inc>\d+)(?<pre>\S+)?'/) do
    m = Regexp.last_match
    major = m['major'].to_i
    minor = m['minor'].to_i
    inc = m['inc'].to_i
    pre = m['pre']

    case args[:type]
    when /^maj/
      major += 1
      minor = 0
      inc = 0
    when /^min/
      minor += 1
      inc = 0
    else
      inc += 1
    end

    $stdout.puts "At version #{major}.#{minor}.#{inc}#{pre}"
    "VERSION = '#{major}.#{minor}.#{inc}#{pre}'"
  end
  File.open(version_file, 'w+') { |f| f.puts content }
end

task default: %i[ver]
