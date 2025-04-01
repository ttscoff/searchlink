# frozen_string_literal: true

module SL
  # Spelling Search
  class SpellSearch
    class << self
      def settings
        {
          trigger: "sp(?:ell)?",
          searches: [
            %w[sp Spelling],
            ["spell", nil]
          ]
        }
      end

      def search(_, search_terms, link_text)
        title = SL.spell(search_terms)

        [title, title, link_text]
      end
    end

    SL::Searches.register "spelling", :search, self
  end

  class << self
    def spell(phrase)
      aspell = if File.exist?("/usr/local/bin/aspell")
                 "/usr/local/bin/aspell"
               elsif File.exist?("/opt/homebrew/bin/aspell")
                 "/opt/homebrew/bin/aspell"
               else
                 `which aspell`.strip
               end

      if aspell.nil? || aspell.empty?
        SL.add_error("Missing aspell", "Install aspell in to allow spelling corrections")
        return false
      end

      words = phrase.split(/\b/)
      output = ""
      words.each do |w|
        if w =~ /[A-Za-z]+/
          spell_res = `echo "#{w}" | #{aspell} --sug-mode=bad-spellers -C pipe | head -n 2 | tail -n 1`
          if spell_res.strip == "\*"
            output += w
          else
            spell_res.sub!(/.*?: /, "")
            results = spell_res.split(/, /).delete_if { |word| phrase =~ /^[a-z]/ && word =~ /[A-Z]/ }
            output += results[0]
          end
        else
          output += w
        end
      end
      output
    end
  end
end
