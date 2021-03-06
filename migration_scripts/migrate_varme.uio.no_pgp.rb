# -*- coding: utf-8 -*-
require '../lib/vortex_static_site_migration'

# Custom code for migrating the joomla site varme.uio.no/pgp site to vortex:
class PGPMigration < StaticSiteMigration

  # Run this before we start migration
  def setup
    # Use som logic names for logfiles:
    @logfile        = 'pgp_migration_log.txt'
    @errors_logfile = 'pgp_migration_error_log.txt'

    # Set up logfile for breadcrumb
    @breadcrumb_log = "varme.uio.no_pgp_breadcrumbs.log"
    File.open(@breadcrumb_log, 'w') do |f|
      f.write('')
    end
  end

  # Migrate all files with .html extension as articles i vortex
  def is_article?(filename)
    if(filename[/index2.php/])
      return false
    end
    if(filename[/\.html$/] )then
      content = open(filename).read
      doc = Nokogiri::HTML(content)
      return (doc.css(".contentheading").first and doc.css(".contentpaneopen").size > 0 and doc.css("#path>.pathway").size > 0)
    end
    return false
  end

  # Convert from ISO-8859-1 to UTF-8
  def iso2utf(string)
    converter = Iconv.new('UTF-8', 'ISO-8859-1')
    return converter.iconv(string)
  end

  def extract_filename
    return extract_filename2(@doc)
  end

  # TODO Bytt ut extract_filename() med en enklere metode for å ekstrahere brødsmulesti:
  def extract_breadcrumb
    # ex:
    #  return ["Home","Projects","Internal"]
  end


  # Returns filename with path.
  # Ex. /methods/fieldwork/geo-patterns.html
  def extract_filename2(doc)
    path = "/"
    breadcrumb = ""

    # Detect the frontpage /corner case
    # if(@doc.css("#path>.pathway>.pathway").size > 0 and @doc.css("#path>.pathway>.pathway a").size == 0)then
    #   return path + "index.html"
    # end

    # binding.pry

    breadcrumb_elements = doc.css("#path>.pathway>.pathway a")
    if(breadcrumb_elements[1..100] == nil) # Dirty hack to fix a bug really originated elsewhere.
      breadcrumb_elements = @doc.css("#path>.pathway>.pathway a")
    end

    if(breadcrumb_elements[1..100] == nil)
      binding.pry
    end

    breadcrumb_elements[1..100].each do |element|
      breadcrumb = breadcrumb + element.text + ";"
      path = path + Vortex::StringUtils.create_filename(element.text) + "/"
    end

    # Add last element of breadcrumb to the generated filepath
    breadcrumb_html = doc.css("#path>.pathway>.pathway").inner_html
    # puts "DEBUG1: '#{breadcrumb_html}'"
    breadcrumb_html = iso2utf(breadcrumb_html)

    last_breadcrumb_element = breadcrumb_html[/<img[^>]*>([^<]*)$/,1].to_s.strip
    # puts "DEBUG2: '#{last_breadcrumb_element}'"
    last_breadcrumb_element = Vortex::StringUtils.create_filename(last_breadcrumb_element)

    title = Vortex::StringUtils.create_filename(extract_title.to_s)
    path = path + last_breadcrumb_element + '/'
    breadcrumb = breadcrumb + extract_title.to_s

    if(last_breadcrumb_element == title)
      filename = path + "index.html"
    else
      filename = path + title + ".html"
    end

    if(path == "/")
      puts "ERROR: No path!"
      exit
    end

    # Log breadcrumb and filepath to file so we can fix foldernames afterwards
    File.open(@breadcrumb_log, 'a') do |f|
      f.write( "#{path}:#{breadcrumb}\n" )
    end

    if(@debug)
      puts "Breadrcrum: " + breadcrumb.gsub(";"," > ")
    end

    return filename
  end

  # Perform checks before publishing
  def pre_publish(destination_filename, data)
    if(@vortex.exists?(destination_filename))
      puts "ERROR: Attempting to rewrite : " + destination_filename
      exit
    end
  end

  # def post_publish(filename)
  # end

  # Return title as string. Mandatory method.
  def extract_title
    @doc.css(".contentheading").first.text.strip if @doc.css(".contentheading").first
  end

  # Split the body part into to separate introduction and body parts
  def extract_introduction
    # binding.pry
    introduction = ""
    @body_element_index = 0 # Start index for the body element

    # First step is to see if there is any content before the first paragraph.
    # Example: "Intro here. <p>More content here</p>"
    @doc.css(".contentpaneopen[2] td").children.each do |element|
      if(element.name == "p")then
        break
      end
      introduction = introduction + element.to_s.strip
      @body_element_index += 1
    end

    # Next step is to extract the first paragraph
    @remove_first_paragraph = false
    if(introduction == "")
      introduction = @doc.css(".contentpaneopen[2] td p[1]").inner_html
      @remove_first_paragraph = true # Tell extract_body to remove something...
      @body_element_index = 2
    end

    # Give up if introduction is to long for vortex.
    if(introduction.size > 1000)then
      @body_element_index = 0
      return ""
    end

    # Clean up html
    introduction = introduction.gsub(/<.?font>/,' ').strip.gsub(/<br.?>$/,'')

    introduction = iso2utf(introduction)
    # introduction = remove_special_chars(introduction)
    return introduction
  end

  def extract_body

    if(@remove_first_paragraph)
      content = @doc.to_s
      # content = transliterate_utf8(content)
      doc = Nokogiri::HTML( content)
      doc.css(".contentpaneopen[2] td p[1]").remove
      body = doc.css(".contentpaneopen").last.css("td").first.inner_html

    else
      body = @doc.css(".contentpaneopen[2] td").children[@body_element_index..1000].to_s.strip
    end
    body = iso2utf(body)
    body = body.gsub(/\s+/,' ')
    # body = remove_special_chars(body)
    return body.strip
  end

  # Når alle andre metoder for å konvertere å parsere iso8859 til utf-8 feiler,
  # så bruk transliteration.
  def remove_special_chars(string)
    string = string.gsub("æ","&aelig;")
    string = string.gsub("ø","&oslash;")
    string = string.gsub("å","&aring;")
    string = string.gsub("Æ","&Aelig;")
    string = string.gsub("Ø","&Oslash;")
    string = string.gsub("Å","&Aring;")

    string = transliterate_utf8(string)

    string = string.gsub(/'/, "\"") # Fnutter gir "not valid xml error"
    string = string.gsub("&nbsp;", " ") # &nbsp; gir også "not valid xml error"
    string = string.gsub("", "-") # Tankestrek til minustegn
    string = string.gsub("”","&#39;")  # Norske gåseøyne til fnutt
    string = string.gsub(/'/,"") # Fnutt
    string = string.gsub("","\"")
    string = string.gsub("", "-") # Tankestrek til minustegn
    string = string.gsub("","") # Fnutt
    string = string.gsub("","") # Fnutt
    string = string.gsub("","") # Fnutt
    string = string.gsub("&", "&amp;")
    string = string.gsub("`","") # Enda en fnutt
    return string
  end


  def transliterate_utf8(string)
    Iconv.iconv('ascii//ignore//translit', 'utf-8', string).to_s
  end


  # Returns false or new url
  def href_is_local_link(href)
    file_uri = href.to_s.sub(/(#|\?).*/,'')

    if( href and (href[/^http:\/\/www.fys.uio.no\/pgp/] or href[/^http:\/\/varme.uio.no\/pgp/]) and  file_uri[/\.php$/])
      # Open the link and see if we can extract filename from its breadcrumb
      doc = Nokogiri::HTML(open(href))
      filename = extract_filename2(doc)
      return @vortex_path + filename.gsub(/^\//,'')
    end
    return nil
  end

  # Return true if link in html file should be migrated to vortex.
  def migrate_linked_file?(uri)
    host = uri.host.to_s
    path = uri.path.to_s
    if(host == 'varme.uio.no' or host == 'www.fys.uio.no')
      if(path != '/' and path != '')
        return true
      else
        return false
      end
    elsif(host != '')
      return false
    end
    return super(uri)
  end


  def download_linked_file?(href)
    file_uri = href.to_s.sub(/(#|\?).*/,'')
    # puts "DEBUG: file_uri: " + file_uri
    if(file_uri[/\.html$/] or file_uri[/\.php$/])
      return false
    end

    # puts "DEBUGGG2002" + href.to_s
    if(href and ( href[/^http:\/\/www.fys.uio.no\/pgp/] or href[/^http:\/\/varme.uio.no\/pgp/] ))
      return true
    end
    return false
    # return super(href)
  end

end

if __FILE__ == $0 then
  #system("cd /tmp;wget --mirror –p --html-extension –-convert-links --force-directories  -e robots=off -P . http://varme.uio.no/pgp/index.php")
  src_dir = '/tmp/varme.uio.no/pgp/'
  webdav_destination = 'https://www-dav.mn.uio.no/konv/pgp/'
  migration = SummerSchoolMigration.new(src_dir,webdav_destination)

  migration.debug = true
  migration.dry_run = false # true
  # migration.migrate_article("index.php?option=com_content&task=view&id=77&Itemid=123.html")
  # PDF files isn't downloaded:
  # migration.migrate_article("index.php?option=com_content&task=view&id=255&Itemid=298.html")
  migration.run


  # migration.generate_report
  # migration.generate_migration_html_report
end
