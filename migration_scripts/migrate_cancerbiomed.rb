# -*- coding: utf-8 -*-
require '../lib/vortex_static_site_migration'

# Super class for dynamic and static site migration
class SiteMigration

  attr_accessor :debug, :logfile, :errors_logfile, :dry_run, :encoding, :vortex, :html_dir, :src_url, :dest_url, :doc_url

  def initialize(src,dest)
    @src_url = src
    @vortex = Vortex::Connection.new(dest, :osx_keychain => true)
    @vortex_path = URI.parse(dest).path
    @dest_url = dest
    @logfile = 'migration_uploads_log.txt'
    @errors_logfile = 'migrarition_errors_log.txt'
    @dirty_uploads_logfile = false
    @dirty_errors_logfile = false
    @dry_run = false
    @debug = true
    @document_count = 0
    @src_hosts = [URI.parse(src).scheme + "://" + URI.parse(src).host]
    setup
  end

  def setup
  end
  # logging

  # Log uploads
  def log_upload(filetype,local_pathname,pathname)
    # Empty logfile first:
    if(@dirty_uploads_logfile == false)then
      File.open(@logfile, 'w') do |f|
        f.write('')
      end
    end

    File.open(@logfile, 'a') do |f|
      f.write( "#{filetype}:#{local_pathname}:#{pathname}\n" )
    end

    @dirty_uploads_logfile = true
  end

  # Log errors
  def log_error(filetype,pathname)
    if(@dirty_errors_logfile == false)then
      # Empty logfile
      File.open(@errors_logfile, 'w') do |f|
        f.write('')
      end
    end

    File.open(@errors_logfile, 'a') do |f|
      f.write( "#{filetype}:#{pathname}\n" )
    end
    @dirty_errors_logfile = true
  end

  # Returns true uri should be downloaded and uploaded to vortex:
  def migrate_linked_file?(uri)
    uri = URI.join(@src_hosts[0],uri)
    @src_hosts.each do |src_host|
      if(uri.host == URI.parse(src_host).host)
        return true
      end
    end
    return false
  end


  # Copy file with file_uri to vortex server
  def upload_file(file_uri, html_filename, destination_path)
    if(file_uri[/^http/])
      # TODO Sjekke at filen ligger på samme server eller annen server
      filename = file_uri
    else
      filename = (Pathname.new(html_filename).parent + Pathname.new(file_uri)).to_s
    end

    basename = Pathname.new(file_uri).basename.to_s
    destination_filename = destination_path + '/' + basename

    content = nil
    begin
      # puts "Filename => " + filename.to_s
      timeout(15) do # Makes open-uri timeout after 10 seconds.
        begin
          content = open(filename).read
        rescue
          puts "Error: Timeout: " + filename
          log_error('timed-out',filename)
          return nil
        end
      end
    rescue
      puts "Logging error: File not found : " + filename if(@debug)
      log_error('file-not-found',filename)
    end
    if(content)then
      puts "File uri  : " + file_uri if(@debug)
      puts "  Copying : " + filename if(@debug)
      puts "  To      : " + destination_filename if(@debug)
      @vortex.put_string(destination_filename, content)
      log_upload('file',  file_uri , destination_filename.sub(@vortex_path,''))
    end
  end


  # Download images and files (pdf, ppt etc) and return updated html.
  def migrate_files(body, destination_path) # , doc_url)
    if(@encoding)
      doc = Nokogiri::HTML(body,nil, @encoding)
    else
      doc = Nokogiri::HTML(body)
    end

    # Upload images to vortex server:
    doc.css("img").each do |image|
      file_uri = image.attr("src")
      file_uri = Pathname.new(doc_url).parent + file_uri

      uri = nil
      begin
        uri = URI.parse(file_uri.to_s)
      rescue
        puts "Logging error: Unparseable link : " + file_uri
        log_error('unparseable-link-in-file',file_uri)
      end

      content = nil
      if(uri and migrate_linked_file?(uri))
        uri = URI.join(@src_hosts[0],uri)
        # puts "   Fetching : " + uri.to_s
        timeout(15) do # Makes open-uri timeout after 10 seconds.
          begin
            content = open(uri.to_s).read
          rescue
            puts "Error: Timeout: " + uri.to_s
            log_error('timed-out',uri.to_s)
          end
        end

        if(content)
          basename = Pathname.new(uri.path).basename.to_s
          destination_filename = destination_path + '/' + basename
          destination_filename = destination_filename.gsub("//","/")
          if(not(@vortex.exists?(destination_filename)))
            @vortex.put_string(destination_filename, content)
          else
            puts "Warning: File exists " + destination_filename
            log_error('file-exists',destination_filename)
          end

        else
          puts "Logging error: File not found : " + uri.to_s if(@debug)
          log_error('file-not-found',uri.to_s)
        end
      end

      basename = Pathname.new(file_uri).basename.to_s
      image.set_attribute("src",basename)
    end

    # Upload files, everything that's not a document, to vortex server:
    doc.css("a").each do |link|
      href = link.attr("href")
      if(href and not(href[/^\#/]))
        file_uri = href.to_s.sub(/(#|\?).*/,'')

        uri = nil
        begin
          uri = URI.parse(href)
        rescue
          puts "Logging error: Unparseable link : " + href
          log_error('unparseable-link-in-file',file_uri)
        end

        if(uri and migrate_linked_file?(uri))
          upload_file(file_uri, uri, destination_path)
          basename = Pathname.new(file_uri).basename.to_s
          link.set_attribute("href",basename)
        end

      end
    end

    if(doc.css("html"))
      return doc.css("body").inner_html.to_s
    else
      return doc.to_s
    end

  end






  # publisering
  def publish_article(new_filename, title, introduction, related, body)
    destination_filename = @vortex_path + new_filename
    destination_filename = destination_filename.gsub("//","/")
    destination_path = Pathname.new(destination_filename).parent.to_s

    @vortex.create_path(destination_path)
    @vortex.cd(destination_path) # Set path so images, and other files, are placed correctly

    body = migrate_files(body, destination_path) # ,@doc_url)

    data = {
      "resourcetype" => "structured-article",
      "properties" =>    {
        "title" => title,
        "content" => body,
        "introduction" => introduction,
        "hideAdditionalContent" => "true"
      }
    }

    # Avoid files beeing rewriten by adding a number at end for filename: index.html => index_2.html
    if(@vortex.exists?(destination_filename))
      index = 1
      new_filename = destination_filename.gsub(".html", "_#{index}.html")
      while(@vortex.exists?( new_filename ))
        index = index + 1
        new_filename = destination_filename.gsub(".html", "_#{index}.html")
      end
      destination_filename = new_filename
    end

    # pre_publish(destination_filename, data)

    @vortex.put_string(destination_filename, data.to_json)
    log_upload('article', @doc_src, destination_filename.sub(@vortex_path,''))

    @vortex.proppatch(destination_filename,'<v:publish-date xmlns:v="vrtx">' + Time.now.httpdate.to_s + '</v:publish-date>')
    if(@debug)
      puts "Published : " + destination_filename
    end

  end

end

# Migrate site by scraping from site. Used when it is not possible to
# get a local copy of the sites html files.
class DynamicSiteMigration < SiteMigration

  # Return information typically found in margin or bottom of page
  def extract_related_content
  end

  #Determine what path and filename the file should be written to
  def extract_filename
    if(extract_breadcrumb)
      puts "using breadcrumb as source"
    end
  end

  # Extract breadrcumb from page so they can be migrated as folder names in vortex
  def extract_breadcrumb

  end

  def migrate_article(url)
    @doc_url = @src_url + url
    @doc = Nokogiri::HTML(open(@doc_url))
    title = extract_title
    introduction = extract_introduction
    body = extract_body
    related = extract_related_content

    new_filename = extract_filename

    if(@debug)
      puts "Count     : " + @document_count.to_s
      @document_count = @document_count + 1
      puts "Title     : " + title.to_s
      puts "Intro     : " + introduction.to_s #[0..140]
      puts "Related   : " + related.to_s[0..140] if(related and related.to_s != "")
      puts "Body      : " + body.to_s[0..140]
      puts "Filename  : " + new_filename if(new_filename != "")
      puts "Dest.     : " + @dest_url + new_filename if(new_filename != "")
    end

    if(not(@dry_run))then
      publish_article(new_filename, title, introduction, related, body)
    end
    if(@debug)
      puts "_" * 80
    end

  end

  def get_children(uri)
    return nil
  end

  # Run complete migration
  def run
  end

end

# Custom code to migrate the site cancerbiomed.net
class CancerbiomedMigration < DynamicSiteMigration # StaticSiteMigration

  def is_article?(url)
    urlfilename[/\.html$/]
  end

  def extract_title
    @doc.css(".subContent h1").first.text.strip
  end

  def extract_introduction
    # binding.pry
    if(@doc.css(".subContent h2").first)
        return @doc.css(".subContent h2").first.inner_html
    end
  end

  def extract_body
    # Remove WordPress HighSlide(tm) image-zoom link from images:
    @doc.css(".highslide").each do |element|
      element.css("img").first.parent = element.parent
      element.remove
    end

    @doc.css(".subContent p:not(.m2)").to_s
  end

  def extract_filename
    path = URI.parse(@doc_url).path  #TOOD denne variablen er ikke global lenger...
    if(path[/\/$/])
      path = path + "index.html"
    end
    return path.gsub("//","/")
  end

  # Returns breadcrumb as a array of strings
  def extract_breadcrumb
    breadcrumb = []
    breadcrumb << @doc.css(".m1 a.active").text
    breadcrumb << @doc.css(".m2 a.active").text
    breadcrumb << @doc.css(".m2a a.active").text
    return breadcrumb
  end

  def path_for_link_element(element)
    return URI.parse(element.attr("href").to_s).path
  end

  # Returns list of relative url's to children documents
  # TODO: Handle relative links to parent directories like '../parent.html'
  def get_children
    # puts "Extracting children from :" + @doc_url
    children = []
    if(@doc.css(".m1 a.active").size > 0)
      if(@doc.css(".m2 a.active").size > 0)

        if(@doc.css(".grandkids a").size > 0)
          # binding.pry
          if( @doc.css(".m2 .grandkids .active").size > 0)
            # This is the bottom of the tree
          else
            @doc.css(".grandkids a").each do |element|
              children << URI.parse( element.attr("href") ).path
            end
          end
        else
          @doc.css(".postKids a").each do |element|
            children << URI.parse( element.attr("href") ).path
          end
        end

      else
        @doc.css(".m2 a").each do |element|
          children << URI.parse( element.attr("href") ).path
        end
      end
    end

    return children
  end

end

if __FILE__ == $0 then
  src  = 'http://www.cancerbiomed.net/'
  dest = 'https://www-dav.vortex-demo.uio.no/konv/cancerbiommed'
  migration = CancerbiomedMigration.new(src, dest)
  migration.debug = true
  # migrate.src_hosts = ["www.cancerbiomed.net"]
  migration.migrate_article('groups/hs/')

end
