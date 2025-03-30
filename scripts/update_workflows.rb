#!/usr/bin/env ruby -W1
# frozen_string_literal: true

SIGNING_ID = "Apple Development: Brett Terpstra"

require "plist"
require "shellwords"

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

class Workflow
  include XmlEscape

  def initialize(workflow)
    @workflow = File.expand_path(workflow)
  end

  def compile
    source_file = File.expand_path("bin/searchlink")
    source = IO.read(source_file)

    source.import_markers!(File.join(File.dirname(source_file), ".."))

    source.sub(/#{Regexp.escape(%($LOAD_PATH.unshift File.join(__dir__, '..')))}/, "")
  end

  def sign
    cmd = [
      "codesign",
      "--force",
      "--deep",
      "--verbose",
      "--sign '#{SIGNING_ID}'",
      "-o runtime",
      "--timestamp",
      Shellwords.escape(@workflow)
    ].join(" ")
    res = `#{cmd} 2>&1`

    return true if res =~ /signed bundle/

    warn res
    false
  end

  def update_script
    wflow = File.join(File.expand_path(@workflow), "Contents/document.wflow")
    script = compile
    IO.read(wflow)

    plist = Plist.parse_xml(wflow)
    plist["actions"].each_with_index do |action, idx|
      next unless action["action"]["AMParameterProperties"].key?("COMMAND_STRING")

      plist["actions"][idx]["action"]["AMParameterProperties"]["COMMAND_STRING"] = script
      break
    end

    File.open(wflow, "w") { |f| f.puts plist.to_plist }
    warn "updated script for #{File.basename(@workflow)}"
  end
end

Dir.glob("SearchLink Services/*.workflow").each do |service|
  wf = Workflow.new(service)
  wf.update_script
  puts wf.sign ? "Signed worfklow #{service}" : "Failure to sign workflow #{service}"
end
