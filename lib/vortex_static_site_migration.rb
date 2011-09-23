# -*- coding: utf-8 -*-
require 'rubygems'
require 'find'
require 'pathname'
require 'nokogiri'
require 'vortex_client'
require 'json'
require 'open-uri'
require 'iconv'
require 'pry' # binding.pry => escapes into irb like shell
$LOAD_PATH.unshift Pathname.new(File.expand_path( __FILE__ )).parent.to_s
require 'vortex_migration_report'
require "net/http"
require "uri"


class StaticSiteMigration

  attr_accessor :debug, :logfile, :errors_logfile, :dry_run, :encoding, :vortex, :html_dir

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
    @logfile = 'migration_uploads_log.txt'
    @errors_logfile = 'migrarition_errors_log.txt'
    @dirty_uploads_logfile = false
    @dirty_errors_logfile = false
    @dry_run = false
    @debug = true
    @document_count = 0
    setup
  end

  #-----------------------------------------
  #
  # Methods that may be overloaded
  #
  #-----------------------------------------

  # Return path and filename
  def extract_filename
  end

  # Return information typically found in margin or bottom of page
  def extract_related_content
  end

  # Will be run before migration starts
  def setup
  end

  # Will be run before publishing html to vortex
  def pre_publish(destination_filename, data)
  end

  def extract_published_date
  end

  #--------------------------------------
  #
  # Methods not to be overloaded
  #
  #--------------------------------------

  # Example "text/html; charset=iso-8859-1"
  def content_type(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    return response.get_fields('Content-Type')
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

    # binding.pry
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
      # Downcase path but not destination_filename:
      arr = destination_filename.split(/\//)
      destination_filename = arr[0..arr.size-2].join("/").downcase + "/" + arr.last

      puts "File uri  : " + file_uri if(@debug)
      puts "  Copying : " + filename if(@debug)
      puts "  To      : " + destination_filename if(@debug)

      if(@vortex.exists?(destination_filename))
        puts "  Warning : " + destination_filename + " exists on server."
      else
        # binding.pry
        @vortex.put_string(destination_filename, content)
        log_upload('file', filename.sub(@html_dir,''), destination_filename.sub(@vortex_path,''))
      end
    end
  end

  # Download images and files (pdf, ppt etc) and return updated html.
  def migrate_files(body, destination_path, html_filename)
    if(@encoding)
      doc = Nokogiri::HTML(body,nil, @encoding)
    else
      doc = Nokogiri::HTML(body)
    end

    # Upload images to vortex server:
    doc.css("img").each do |image|
      file_uri = image.attr("src")

      # binding.pry

      # Handle relative url's like '../../images/headinglogo.gif':
      if(file_uri[/^\//])
        file_uri = @html_dir + file_uri
      elsif(not(file_uri[/^\//]) and not(file_uri[/^http/]))then
        file_uri = Pathname.new(html_filename).parent + file_uri
      end

      uri = nil
      begin
        uri = URI.parse(file_uri.to_s)
      rescue
        puts "Logging error: Unparseable link : " + file_uri
        log_error('unparseable-link-in-file',file_uri)
      end

      if(uri and migrate_linked_file?(uri))
        if(File.exists?(uri.to_s))
          upload_file(uri.to_s, html_filename, destination_path)
        else
          puts "Logging error: File not found : " + file_uri if(@debug)
          log_error('file-not-found',file_uri)
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
          upload_file(file_uri, html_filename, destination_path)
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


  # Used to check if an url in link is a file that should be downloaded.
  # Should be overloaded if there is special rules for site
  def migrate_linked_file?(uri) # href)
    href = uri.to_s
    file_uri = href.to_s.sub(/(#|\?).*/,'')

    if(href == nil or href[/^mailto:/])
      return false
    end

    if(is_article?(file_uri))
    # if(file_uri[/html$/])
      return false
    end

    return true
  end

  def make_links_relative(body, destination_path, html_filename)
    if(@encoding)
      doc = Nokogiri::HTML(body,nil, @encoding)
    else
      doc = Nokogiri::HTML(body)
    end

    doc.css('a').each do |link|
      href = link['href']
      uri = nil
      begin
        uri = URI.parse(href.to_s)
      rescue
        puts "Logging error: Unparseable link : " + href.to_s
        log_error('unparseable-link-in-file',destination_path)
      end
      if(uri and href and href[/^\//] )then
        pathname_from = Pathname.new( destination_path )
        pathname_to   = Pathname.new( uri.path.to_s )
        new_href = pathname_to.relative_path_from(pathname_from.parent).to_s
        link.set_attribute('href',new_href)
        puts "Update url : " + href + " => " + new_href
      end
    end

    if(doc.css("html"))
      return doc.css("body").inner_html.to_s
    else
      return doc.to_s
    end
  end

  # Convert from ISO-8859-1 to UTF-8
  def iso2utf(string)
    converter = Iconv.new('UTF-8', 'ISO-8859-1')
    return converter.iconv(string)
  end

  # Download images and other files, update html and publish an article
  def publish_article(html_filename, title, introduction, related, body, new_filename)
    if(new_filename == "")
      destination_filename = @vortex_path + html_filename.sub(@html_dir,'')
      destination_filename = destination_filename.gsub(/\/\/*/,'/')
      destination_path = Pathname.new(destination_filename).parent.to_s
    else
      destination_filename = @vortex_path + new_filename
      destination_filename = destination_filename.gsub("//","/")
      destination_path = Pathname.new(destination_filename).parent.to_s
    end

    @vortex.create_path(destination_path)
    @vortex.cd(destination_path) # Set path so images, and other files, are placed correctly

    if(@encoding and @encoding[/^iso/i])
      introduction = iso2utf(introduction)
      body = iso2utf(body)
    end

    # Download and upload images etc. and make links relative.
    introduction = migrate_files(introduction, destination_path, html_filename)
    introduction = make_links_relative(introduction, destination_path, html_filename)
    body = migrate_files(body, destination_path, html_filename)
    body = make_links_relative(body, destination_path, html_filename)

    # Extract images from introduction and set as article image
    doc = Nokogiri::HTML(introduction)
    picture = nil
    if(doc.css("img").first)
      picture = doc.css("img").first.attr("src")
      doc.css("img").remove
      introduction = doc.css("body").inner_html
    end

    data = {
      "resourcetype" => "structured-article",
      "properties" =>    {
        "title" => title,
        "content" => body,
        "introduction" => introduction,
        "hideAdditionalContent" => "true"
      }
    }

    if(picture)
      data["properties"]["picture"] = picture
    end

    if(related)then
      related = migrate_files(related, destination_path, html_filename)
      related = make_links_relative(related, destination_path, html_filename)

      data["properties"]["hideAdditionalContent"] = "false"
      data["properties"]["related-content"] = related
    end

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

    # Downcase path but not destination_filename:
    arr = destination_filename.split(/\//)
    destination_filename = arr[0..arr.size-2].join("/").downcase + "/" + arr.last

    pre_publish(destination_filename, data)

    puts "Creating  :" + destination_filename

    @vortex.put_string(destination_filename, data.to_json)
    log_upload('article', html_filename.sub(@html_path,''), destination_filename.sub(@vortex_path,''))

    # Set published date:
    published_date = extract_published_date
    if(published_date)
      if(not(published_date.class == Time))
        puts "ERROR. Bad published date"
        exit
      end
        puts "Date      : " + published_date.to_s
      @vortex.proppatch(destination_filename,'<v:publish-date xmlns:v="vrtx">' + published_date.httpdate.to_s + '</v:publish-date>')
    else
      @vortex.proppatch(destination_filename,'<v:publish-date xmlns:v="vrtx">' + Time.now.httpdate.to_s + '</v:publish-date>')
    end

    if(@debug)
      puts "Published : " + destination_filename
    end
  end

  def migrate_article(html_filename)
    if(html_filename[/^[^\/]/] )then
      html_filename = (@html_path + html_filename).to_s
    end

    if(@debug)
      puts "Migrating : " + html_filename
    end
    content = open(html_filename).read

    if(@encoding)
      @doc = Nokogiri::HTML(content,nil, @encoding)
    else
      @doc = Nokogiri::HTML(content)
    end

    # puts @doc.to_s

    if(@doc.css('meta[http-equiv="refresh"]').size > 0)
      puts "Warning   : Ignoring redirect to '" + @doc.css('meta[http-equiv="refresh"]').to_s + "'" if(@debug)
      log_error("redirect",html_filename)
      return
    end

    title = extract_title
    introduction = extract_introduction.strip
    begin
      related = extract_related_content
    rescue
      related = nil
    end
    body = extract_body

    new_filename = extract_filename.to_s

    if(@debug)
      puts "Count     : " + @document_count.to_s
      @document_count = @document_count + 1
      puts "Title     : " + title.to_s
      puts "Intro     : " + introduction.to_s #[0..140]
      puts "Related   : " + related.to_s[0..140] if(related.to_s != "")
      puts "Body      : " + body.to_s[0..140]
      puts "Filename  : " + new_filename if(new_filename != "")
    end

    if(not(@dry_run))then
      publish_article(html_filename, title, introduction, related, body, new_filename)
    end
    if(@debug)
      puts "_" * 80
    end
  end

  # Run migration (eg. main method)
  def run
    start
    transfer_unused_files
    generate_report
    generate_migration_html_report
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

  # Create folders on webdav server for reports and unused files
  def create_reports_folder
    foldername = @vortex_path + 'nettpublisering/'
    if(not(@vortex.exists?(foldername)))then
      puts "Creating report folder : " + foldername
      puts "Creating folder : " + foldername
      @vortex.create_path(foldername)
      @vortex.proppatch(foldername,
              '<hidden xmlns="http://www.uio.no/navigation">true</hidden>')
      @vortex.proppatch(foldername,
              '<v:userTitle xmlns:v="vrtx">Nettpublisering</v:userTitle>')
      @vortex.proppatch(foldername,
              '<v:navigationTitle xmlns:v="vrtx">Nettpublisering</v:navigationTitle>')
      @vortex.proppatch(foldername,
              '<v:introduction xmlns:v="vrtx">&lt;p&gt;Logg inn for &amp;aring; se de ulike ' +
              'rapportene eller filer som ikke er tatt med i migrering.&lt;/p&gt;&#13;</v:introduction>')
    end

    foldername = @vortex_path + 'nettpublisering/rapporter/'
    if(not(@vortex.exists?(foldername)))then
      puts "Creating report folder : " + foldername
      @vortex.create_path(foldername)
      @vortex.proppatch(foldername,
              '<v:userTitle xmlns:v="vrtx">Rapporter for arbeidet med kvalitet på nett</v:userTitle>')
      @vortex.proppatch(foldername,
              '<v:navigationTitle xmlns:v="vrtx">Rapporter</v:navigationTitle>')
      @vortex.proppatch(foldername,
              '<v:introduction xmlns:v="vrtx">&lt;p&gt;Logg inn for &amp;aring; se de ulike ' +
              'rapportene eller filer som ikke er tatt med i migrering.&lt;/p&gt;&#13;</v:introduction>')
    end

    foldername = @vortex_path + 'nettpublisering/ikke_migrert_innhold/'
    if(not(@vortex.exists?(foldername)))then
      puts "Creating folder for unused content: " + foldername
      @vortex.create_path(foldername)
      @vortex.proppatch(foldername,
              '<v:navigationTitle xmlns:v="vrtx">Ikke migrert innhold</v:navigationTitle>')
      @vortex.proppatch(foldername,
              '<v:userTitle xmlns:v="vrtx">Ikke migrert innhold</v:userTitle>')
      @vortex.proppatch(foldername,
              '<v:introduction xmlns:v="vrtx">&lt;p&gt;Logg inn for &amp;aring; se de ulike ' +
              'filene som ikke er tatt med i migrering.&lt;/p&gt;&#13;</v:introduction>')
    end
  end

  # Transfer unused files to vortex
  def transfer_unused_files
    report_data = collect_report_data
    unpublished_files = report_data['unpublished_files']
    create_reports_folder

    foldername = @vortex_path + 'nettpublisering/ikke_migrert_innhold/'
    unpublished_files.each do |filename|
      local_filename = @html_path.to_s + filename
      local_filenamme = local_filename.gsub(/\/\/*/,'/')
      remote_filename = foldername + filename
      remote_path = Pathname.new(remote_filename).parent.to_s
      content = open(local_filename).read
      basename = Pathname.new(remote_filename).basename.to_s
      basename = URI.encode(basename)

      puts "Transfering unused file to server: " + remote_path.downcase + '/' + basename
      @vortex.create_path(remote_path)
      @vortex.put_string(remote_path.downcase + '/' + basename, content)
    end

  end

end
