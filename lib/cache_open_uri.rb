require 'rubygems'
require 'open-uri'
require 'cgi'

# Returns content of url. Uses cache to speed things up.
def open_cached(url)
  tmp_folder = "/tmp/open_uri_cache/"
  filename = tmp_folder + CGI::escape(url)
  if(File.exists?(filename))
    return open(filename).read
  end

  uri = URI.parse(url)
  content = nil
  if(uri.host)
    content = open(url).read
  end

  if(not(File.directory?(tmp_folder)))
    Dir.mkdir(tmp_folder)
  end
  File.open(filename, 'w') {|f| f.write(content) }

  return content
end

if __FILE__ == $0 then
  content = open_cached('http://www.vg.no/')
  puts content[0..100]
end



