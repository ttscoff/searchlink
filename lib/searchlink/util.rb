module SL
  module Util
    class << self
      ## Execute system command with deadman's switch
      ##
      ## <https://stackoverflow.com/questions/8292031/ruby-timeouts-and-system-commands>
      ## <https://stackoverflow.com/questions/12189904/fork-child-process-with-timeout-and-capture-output>
      ##
      ## @param      cmd      The command to execute
      ## @param      timeout  The timeout
      ##
      ## @return     [String] STDOUT output
      ##
      def exec_with_timeout(cmd, timeout)
        begin
          # stdout, stderr pipes
          rout, wout = IO.pipe
          rerr, werr = IO.pipe
          stdout, stderr = nil

          pid = Process.spawn(cmd, pgroup: true, out: wout, err: werr)

          Timeout.timeout(timeout) do
            Process.waitpid(pid)

            # close write ends so we can read from them
            wout.close
            werr.close

            stdout = rout.readlines.join
            stderr = rerr.readlines.join
          end
        rescue Timeout::Error
          Process.kill(-9, pid)
          Process.detach(pid)
        ensure
          wout.close unless wout.closed?
          werr.close unless werr.closed?
          # dispose the read ends of the pipes
          rout.close
          rerr.close
        end

        stdout&.strip
      end

      ##
      ## Execute a search with deadman's switch
      ##
      ## @param      search   [Proc] The search command
      ## @param      timeout  [Number] The timeout
      ##
      ## @return     [Array] url, title, link_text
      ##
      def search_with_timeout(search, timeout)
        url = nil
        title = nil
        link_text = nil

        begin
          Timeout.timeout(timeout) do
            url, title, link_text = search.call
          end
        rescue Timeout::Error
          SL.add_error('Timeout', 'Search timed out')
          url, title, link_text = false
        end

        [url, title, link_text]
      end

      ##
      ## Get the path for a cache file
      ##
      ## @param      filename  [String]  The filename to
      ##                       generate the cache for
      ##
      ## @return     [String] path to new cache file
      ##
      def cache_file_for(filename)
        cache_folder = File.expand_path('~/.config/searchlink/cache')
        FileUtils.mkdir_p(cache_folder) unless File.directory?(cache_folder)
        File.join(cache_folder, filename.sub(/(\.cache)?$/, '.cache'))
      end
    end
  end
end
