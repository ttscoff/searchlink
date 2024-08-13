# frozen_string_literal: true

require 'rake/clean'
require 'rubygems'
require 'bundler/gem_tasks'
require 'rubygems/package_task'
require 'rdoc'
require 'rdoc/task'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'
require 'tty-spinner'

task default: %i[test yard]

desc 'Alias for build'
task package: :build

desc 'Run test suite'
# task test: %i[rubocop spec]
task test: %i[rubocop spec]

RSpec::Core::RakeTask.new

RuboCop::RakeTask.new do |t|
  t.formatters = %w[progress]
end

YARD::Rake::YardocTask.new

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
  res = `grep VERSION lib/searchlink/version.rb`
  version = res.match(/VERSION *= *['"](\d+\.\d+\.\d+(\w+)?)/)[1]
  puts "git tag: #{gver}"
  puts "version.rb: #{version}"
  puts "changelog: #{cver}"
end

desc 'Get Script Version'
task :sver do
  res = `grep VERSION lib/searchlink/version.rb`
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
  version_file = 'lib/searchlink/version.rb'
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

namespace :spec do
  FileList['spec/*_spec.rb'].each do |spec|
    test_name = File.basename(spec, '.rb').sub(/^(.*?)_spec$/, '\1')

    RSpec::Core::RakeTask.new(:"#{test_name}") do |t|
      t.pattern = spec
    end

    # Define default task for :spec
    task default: test_name
  end
end

SIGNING_ID = 'Apple Development: Brett Terpstra'

require 'plist'
require 'shellwords'
require 'fileutils'

class Workflow
  # String helpers
  class ::String
    def import_markers(base)
      gsub(/^# *import\nrequire(?:_relative)? '(.*?)'\n/) do
        file = Regexp.last_match(1)
        file = File.join(base, "#{file}.rb")

        content = IO.read(file)
        content.import_markers(File.dirname(file))
      end
    end

    def import_markers!(base)
      replace import_markers(base)
    end
  end

  def initialize(workflow)
    @workflow = File.expand_path(workflow)
  end

  def self.copy_services
    services = ['SearchLink', 'SearchLink File', 'Jump to SearchLink Error']
    target = File.expand_path('./SearchLink Services')
    services.each do |service|
      source = File.join(File.expand_path('~/Library/Services'), "#{service}.workflow")
      FileUtils.cp_r(source, target)
    end
  end

  def compile
    source_file = File.expand_path('bin/searchlink')
    source = IO.read(source_file)

    source.import_markers!(File.join(File.dirname(source_file), '..'))

    source.sub(/#{Regexp.escape(%($LOAD_PATH.unshift File.join(__dir__, '..')))}/, '')
  end

  def sign
    cmd = [
      'codesign',
      '--force',
      '--deep',
      '--verbose',
      "--sign '#{SIGNING_ID}'",
      '-o runtime',
      '--timestamp',
      Shellwords.escape(@workflow)
    ].join(' ')
    res = `#{cmd} 2>&1`

    return true if res =~ /signed bundle/

    warn res
    false
  end

  def update_script
    wflow = File.join(File.expand_path(@workflow), 'Contents/document.wflow')
    script = compile
    workflow = IO.read(wflow)

    plist = Plist.parse_xml(wflow)
    plist['actions'].each_with_index do |action, idx|
      next unless action['action']['AMParameterProperties'].key?('COMMAND_STRING')

      plist['actions'][idx]['action']['AMParameterProperties']['COMMAND_STRING'] = script
      break
    end

    File.open(wflow, 'w') { |f| f.puts plist.to_plist }
    "Updated script for #{File.basename(@workflow)}"
  end
end

desc 'Update and sign Services'
task :services do
  workflows = Dir.glob('SearchLink Services/*.workflow')
  if workflows.count < 3
    Workflow.copy_services
  end

  workflows.each do |service|
    wf = Workflow.new(service)
    print wf.update_script
    puts wf.sign ? "... and signed" : "... and FAILED to sign"
  end
end
