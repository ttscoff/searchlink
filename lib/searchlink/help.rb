module SL
  class SearchLink
    def help_text
      text = <<~EOHELP
        -- [Available searches] -------------------
        #{SL::Searches.available_searches}
      EOHELP

      if SL.config['custom_site_searches']
        text += "\n-- [Custom Searches] ----------------------\n"
        SL.config['custom_site_searches'].each { |label, site| text += "!#{label}#{label.spacer} #{site}\n" }
      end
      text
    end

    def help_dialog
      text = "[#{SL.version_check}]\n\n"
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
end
