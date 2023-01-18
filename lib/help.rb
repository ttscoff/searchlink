class SearchLink
  def spacer(str)
    len = str.length
    str.scan(/[mwv]/).each { len += 1 }
    str.scan(/t/).each { len -= 1 }
    case len
    when 0..3
      "\t\t"
    when 4..12
      " \t"
    end
  end

  def help_text
    text = <<~EOHELP
      -- [Available searches] -------------------
      #{available_searches}
    EOHELP

    if @cfg['custom_site_searches']
      text += "\n-- [Custom Searches] ----------------------\n"
      @cfg['custom_site_searches'].each { |label, site| text += "!#{label}#{spacer(label)} #{site}\n" }
    end
    text
  end

  def help_dialog
    text = "[#{version_check}]\n\n"
    text += help_text
    text += "\nClick \\\"More Help\\\" for additional information"
    text.gsub!(/\n/, '\\\n')
    res = `osascript <<'APPLESCRIPT'
set _res to display dialog "#{text}" buttons {"OK", "More help"} default button "OK" with title "SearchLink Help"

return button returned of _res
APPLESCRIPT
    `.strip
    `open https://github.com/ttscoff/searchlink/wiki` if res == 'More help'
  end

  def help_cli
    $stdout.puts help_text
  end
end
