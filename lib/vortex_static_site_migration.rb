require 'rubygems'
require 'find'
require 'pathname'
require 'nokogiri'
require 'vortex_client'
require 'json'
$LOAD_PATH.unshift Pathname.new(File.expand_path( __FILE__ )).parent.to_s
require 'vortex_migration_report'

class StaticSiteMigration

  attr_accessor :debug, :logfile, :errors_logfile

  def initialize(html_dir, url)
    if(html_dir[/^\./])then
      pathname = Pathname.new( File.expand_path(__FILE__) ).parent + html_dir
      html_dir = pathname.to_s
    end
    @html_dir = html_dir
    @html_path = Pathname.new(@html_dir)
    @vortex_path = URI.parse(url).path
    @url = url
    @vortex = Vortex::Connection.new(url, :osx_keychain => true)
    @logfile = 'vortex_uploads_log.txt'
    @errors_logfile = 'vortex_migrarition_errors_log.txt'
    @dirty_uploads_logfile = false
    @dirty_errors_logfile = false
  end


  def zzzz_print_migration_report()
    puts "Migration report"
    puts
    # uploads_log = open(@logfile).read
    # TODO Complete this...
  end


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
      puts "DEBUG: #{filetype}:#{local_pathname}:#{pathname}\n"
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

  # Copy file with file_uri to vortex server
  def upload_file(file_uri, html_filename, destination_path)
    filename = (Pathname.new(html_filename).parent + Pathname.new(file_uri)).to_s
    basename = Pathname.new(file_uri).basename.to_s
    destination_filename = destination_path + '/' + basename
    begin
      content = open(filename).read
    rescue
      puts "Logging error: File not found : " + filename if(@debug)
      log_error('file-not-found',filename)
    end
    if(content)then
      puts "File uri  : " + file_uri if(@debug)
      puts "  Copying : " + filename if(@debug)
      puts "  To      : " + destination_filename if(@debug)
      @vortex.put_string(destination_filename, content)
      # log_upload('file', destination_filename)
      log_upload('file', filename.sub(@html_dir,''), destination_filename.sub(@vortex_path,''))
    end
  end

  # Download images and files (pdf, ppt etc) and return updated html.
  def migrate_files(body, destination_path, html_filename)
    doc = Nokogiri::HTML(body)

    # Upload images to vortex server:
    doc.css("img").each do |image|
      file_uri = image.attr("src")
      if(not(file_uri[/^http/]))then
        upload_file(file_uri, html_filename, destination_path)
        basename = Pathname.new(file_uri).basename.to_s
        image.set_attribute("src",basename)
      else
        throw "File not found: " + file_uri
      end
    end

    # Upload files, everything that's not a document, to vortex server:
    doc.css("a").each do |link|
      href = link.attr("href")
      file_uri = href.to_s.sub(/(#|\?).*/,'')

      # TODO: Should use not(is_article?(...) to detect if it's document or not.
      if(href and not(file_uri[/html$/]) and not(file_uri[/^http/]) and not(href[/^mailto:/]))then
        upload_file(file_uri, html_filename, destination_path)
        basename = Pathname.new(file_uri).basename.to_s
        link.set_attribute("href",basename)
      end
    end

    return doc.to_s
  end

  def make_links_relative(body, destination_path, html_filename)
    doc = Nokogiri::HTML(body)

    doc.css('a').each do |link|
      href = link['href']
      # TODO Check if href equals http://source-site/

      if(href and href[/^\//] )then
        pathname_from = Pathname.new( destination_path )
        pathname_to   = Pathname.new( URI.parse(href.to_s).path.to_s )
        new_href = pathname_to.relative_path_from(pathname_from.parent).to_s
        link.set_attribute('href',new_href)
        puts "Update url : " + href + " => " + new_href
      end
    end

    return doc.to_s
  end

  # Download images and other files, update html and publish an article
  def publish_article(html_filename, title, introduction, body)
    destination_filename = @vortex_path + html_filename.sub(@html_dir,'')
    destination_path = Pathname.new(destination_filename).parent.to_s
    @vortex.create_path(destination_path)
    @vortex.cd(destination_path) # Set path so images, and other files, are placed correctly

    body = migrate_files(body, destination_path, html_filename)
    body = make_links_relative(body, destination_path, html_filename)

    data = {
      "resourcetype" => "structured-article",
      "properties" =>    {
        "title" => title,
        "content" => body,
        "introduction" => introduction,
        "hideAdditionalContentEvent" => "true"
      }
    }

    @vortex.put_string(destination_filename, data.to_json)
    log_upload('article', html_filename.sub(@html_path,''), destination_filename.sub(@vortex_path,''))

    @vortex.proppatch(destination_filename,'<v:publish-date xmlns:v="vrtx">' + Time.now.httpdate.to_s + '</v:publish-date>')
    puts "Published: " + destination_filename
  end


  def migrate_article(html_filename)
    if(html_filename[/^[^\/]/] )then
      html_filename = (@html_path + html_filename).to_s
    end
    puts "Migrating : " + html_filename
    content = open(html_filename).read
    @doc = Nokogiri::HTML(content)
    title = extract_title
    introduction = extract_introduction
    body = extract_body
    puts "Title     : " + title
    puts "Intro     : " + introduction
    # puts "Body      : " + body
    publish_article(html_filename, title, introduction, body)
    puts "___________________________________________________"
  end

  # Find all files and migrate
  def start
    Find.find(@html_dir) do |path|
      if FileTest.directory?(path)
        if File.basename(path)[0] == ?.
          Find.prune
        end
      else
        if(is_article?(path))
          migrate_article(path)
        end
      end
    end
  end

end
