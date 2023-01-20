module SL
  class SearchLink
    def spotlight(query)
      res = `mdfind '#{query}' 2>/dev/null|head -n 1`
      return [false, query] if res.strip.empty?
      title = File.basename(res)
      ["file://#{res.strip.gsub(/ /, '%20')}", title, title]
    end
  end
end
