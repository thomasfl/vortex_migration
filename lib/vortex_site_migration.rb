# -*- coding: utf-8 -*-
require 'vortex_client'
require 'open-uri'

# Super class for dynamic and static site migration
class VortexSiteMigration

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
      # binding.pry
      filename = (Pathname.new(html_filename.to_s).parent + Pathname.new(file_uri)).to_s
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

      if(file_uri[/^\./])
        file_uri = Pathname.new(doc_url).parent + file_uri
      end

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
        # "introduction" => introduction,
        "hideAdditionalContent" => "true"
      }
    }

    if(introduction)
      data["properties"]["introduction"] = introduction
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

    # pre_publish(destination_filename, data)

    @vortex.put_string(destination_filename, data.to_json)
    log_upload('article', @doc_src, destination_filename.sub(@vortex_path,''))

    @vortex.proppatch(destination_filename,'<v:publish-date xmlns:v="vrtx">' + Time.now.httpdate.to_s + '</v:publish-date>')
    if(@debug)
      puts "Published : " + destination_filename
    end

  end



  # Determines if a shell command exists by searching for it in ENV['PATH'].
  def command_exists?(command)
    ENV['PATH'].split(File::PATH_SEPARATOR).any? {|d| File.exists? File.join(d, command) }
  end

  # Returns [width, height] of terminal when detected, nil if not detected.
  # Think of this as a simpler version of Highline's Highline::SystemExtensions.terminal_size()
  def detect_terminal_size
    if (ENV['COLUMNS'] =~ /^\d+$/) && (ENV['LINES'] =~ /^\d+$/)
      [ENV['COLUMNS'].to_i, ENV['LINES'].to_i]
    elsif (RUBY_PLATFORM =~ /java/ || (!STDIN.tty? && ENV['TERM'])) && command_exists?('tput')
      [`tput cols`.to_i, `tput lines`.to_i]
    elsif STDIN.tty? && command_exists?('stty')
      `stty size`.scan(/\d+/).map { |s| s.to_i }.reverse
    else
      nil
    end
  rescue
    nil
  end


end
