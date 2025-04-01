# frozen_string_literal: true

module SL
  class SearchLink
    def help_css
      <<~ENDCSS
        body{-webkit-font-smoothing:antialiased;font-family:"Avenir Next",Avenir,"Helvetica Neue",Helvetica,Arial,Verdana,sans-serif;
        margin:30px 0 0;padding:0;background:#fff;color:#303030;font-size:16px;line-height:1.5;text-align:center}h1{color:#000}
        h2{color:#111}p,td,div{color:#111;font-family:"Avenir Next",Avenir,"Helvetica Neue",Helvetica,Arial,Verdana,sans-serif;
        word-wrap:break-word}a{color:#de5456;text-decoration:none;-webkit-transition:color .2s ease-in-out;
        -moz-transition:color .2s ease-in-out;-o-transition:color .2s ease-in-out;-ms-transition:color .2s ease-in-out;
        transition:color .2s ease-in-out}a:hover{color:#3593d9}h1,h2,h3,h4,h5{margin:2.75rem 0 2rem;font-weight:500;line-height:1.15}
        h1{margin-top:0;font-size:2em}h2{font-size:1.7em}ul,ol,pre,table,blockquote{margin-top:2em;margin-bottom:2em}
        caption,col,colgroup,table,tbody,td,tfoot,th,thead,tr{border-spacing:0}table{border:1px solid rgba(0,0,0,0.25);
        border-collapse:collapse;display:table;empty-cells:hide;margin:-1px 0 1.3125em;padding:0;table-layout:fixed;margin:0 auto}
        caption{display:table-caption;font-weight:700}col{display:table-column}colgroup{display:table-column-group}
        tbody{display:table-row-group}tfoot{display:table-footer-group}thead{display:table-header-group}
        td,th{display:table-cell}tr{display:table-row}table th,table td{font-size:1.2em;line-height:1.3;padding:.5em 1em 0}
        table thead{background:rgba(0,0,0,0.15);border:1px solid rgba(0,0,0,0.15);border-bottom:1px solid rgba(0,0,0,0.2)}
        table tbody{background:rgba(0,0,0,0.05)}table tfoot{background:rgba(0,0,0,0.15);border:1px solid rgba(0,0,0,0.15);
        border-top:1px solid rgba(0,0,0,0.2)}p{font-size:1.1429em;line-height:1.72em;margin:1.3125em 0}dt,th{font-weight:700}
        table tr:nth-child(odd),table th:nth-child(odd),table td:nth-child(odd){background:rgba(255,255,255,0.06)}
        table tr:nth-child(even),table td:nth-child(even){background:rgba(200,200,200,0.25)}
        input[type=text] {padding: 5px;border-radius: 5px;border: solid 1px #ccc;font-size: 20px;}
      ENDCSS
    end

    def help_js
      <<~EOJS
        function filterTable() {
          let input, filter, table, tr, i, txtValue;
          input = document.getElementById("filter");
          filter = input.value.toUpperCase();
          table = document.getElementById("searches");
          table2 = document.getElementById("custom");

          tr = table.getElementsByTagName("tr");

          for (i = 0; i < tr.length; i++) {
              txtValue = tr[i].textContent || tr[i].innerText;
              if (txtValue.toUpperCase().indexOf(filter) > -1) {
                tr[i].style.display = "";
              } else {
                tr[i].style.display = "none";
              }
          }

          tr = table2.getElementsByTagName("tr");

          for (i = 0; i < tr.length; i++) {
              txtValue = tr[i].textContent || tr[i].innerText;
              if (txtValue.toUpperCase().indexOf(filter) > -1) {
                tr[i].style.display = "";
              } else {
                tr[i].style.display = "none";
              }
          }
        }
      EOJS
    end

    def help_text
      text = <<~EOHELP
        -- [Available searches] -------------------
        #{SL::Searches.available_searches}
      EOHELP

      if SL.config["custom_site_searches"]
        text += "\n-- [Custom Searches] ----------------------\n"
        SL.config["custom_site_searches"].sort_by do |l, _s|
          l
        end.each { |label, site| text += "!#{label}#{label.spacer} #{site}\n" }
      end
      text
    end

    def help_html
      out = ['<input type="text" id="filter" onkeyup="filterTable()" placeholder="Filter searches">']
      out << "<h2>Available Searches</h2>"
      out << SL::Searches.available_searches_html
      out << "<h2>Custom Searches</h2>"
      out << '<table id="custom">'
      out << "<thead><td>Shortcut</td><td>Search Type</td></thead>"
      out << "<tbody>"
      SL.config["custom_site_searches"].each do |label, site|
        out << "<tr><td><code>!#{label}</code></td><td>#{site}</td></tr>"
      end
      out << "</tbody>"
      out << "</table>"
      out.join("\n")
    end

    def help_dialog
      text = ["<html><head><style>#{help_css}</style><script>#{help_js}</script></head><body>"]
      text << "<h1>SearchLink Help</h1>"
      text << "<p>[#{SL.version_check}] [<a href='https://github.com/ttscoff/searchlink/wiki'>Wiki</a>]</p>"
      text << help_html
      text << '<p><a href="https://github.com/ttscoff/searchlink/wiki">Visit the wiki</a> for additional information</p>'
      text << "</body>"
      html_file = File.expand_path("~/.searchlink_searches.html")
      File.open(html_file, "w") { |f| f.puts text.join("\n") }
      `open #{html_file}`
    end

    def help_cli
      $stdout.puts help_text
    end
  end
end
