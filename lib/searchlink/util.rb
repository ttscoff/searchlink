module SL
  module Util
    class << self
      def exec_with_timeout(cmd, timeout)
        begin
          # stdout, stderr pipes
          rout, wout = IO.pipe
          rerr, werr = IO.pipe
          stdout, stderr = nil
          
          pid = Process.spawn(cmd, pgroup: true, :out => wout, :err => werr)
          
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
        
        stdout
      end

      def search_with_timeout(p, timeout)
        url = nil
        title = nil
        link_text = nil

        begin
          Timeout.timeout(timeout) do
            url, title, link_text = p.call
          end
        rescue Timeout::Error
          SL.add_error('Timeout', 'Search timed out')
          url, title, link_text = false
        end

        [url, title, link_text]
      end

      def cache_file_for(filename)
        cache_folder = File.expand_path('~/.local/share/searchlink/cache')
        FileUtils.mkdir_p(cache_folder) unless File.directory?(cache_folder)
        File.join(cache_folder, filename.sub(/(\.cache)?$/, '.cache'))
      end
    end
  end
end
