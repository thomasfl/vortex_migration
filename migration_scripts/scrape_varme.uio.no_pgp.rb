# -*- coding: utf-8 -*-
require '../lib/vortex_static_site_migration'

# Custom code for migrating the joomla site varme.uio.no/pgp site to vortex:
class SummerSchoolMigration < StaticSiteMigration

  # Perform setup
  def setup
    # Set up logfile for breadcrumb
    @breadcrumb_log = "varme.uio.no_pgp_breadcrumbs.log"
    File.open(@breadcrumb_log, 'w') do |f|
        f.write('')
      end
  end

  # Migrate all files with .html extension as articles i vortex
  def is_article?(filename)
    if(filename[/index.php.*\.html$/] )then
      content = open(filename).read
      # puts "Source    : " + content # .gsub(/\s+/,' ')# [0..80]
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

  # Returns filename with path.
  # Ex. /methods/fieldwork/geo-patterns.html
  def extract_filename
    path = "/"
    breadcrumb = ""

    # Detect the frontpage /corner case
    if(@doc.css("#path>.pathway>.pathway").size > 0 and @doc.css("#path>.pathway>.pathway a").size == 0)then
      return path + "index.html"
    end

    @doc.css("#path>.pathway>.pathway a")[1..100].each do |element|
      breadcrumb = breadcrumb + element.text + ";"
      path = path + Vortex::StringUtils.create_filename(element.text) + "/"
    end

    # Add last element of breadcrumb to the generated filepath
    breadcrumb_html = @doc.css("#path>.pathway>.pathway").inner_html
    breadcrumb_html = iso2utf(breadcrumb_html)

    last_breadcrumb_element = breadcrumb_html[/<img[^>]*>([^<]*)$/,1].strip
    last_breadcrumb_element = Vortex::StringUtils.create_filename(last_breadcrumb_element)
    title = Vortex::StringUtils.create_filename(extract_title.to_s)
    if(not(last_breadcrumb_element == title))
      path = path + last_breadcrumb_element + '/'
      breadcrumb = breadcrumb + extract_title.to_s
    end

    # Log breadcrumb and filepath to file so we can fix foldernames afterwards
    File.open(@breadcrumb_log, 'a') do |f|
      f.write( "#{path}:#{breadcrumb}\n" )
    end

    if(@debug)
      puts "Breadrcrum: " + breadcrumb.gsub(";"," > ")
    end

    if(path == "/")
      puts "ERROR: No path!"
      exit
    end

    return path + title + ".html"
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
    if(introduction == "")
      introduction = @doc.css(".contentpaneopen[2] td p[1]").inner_html
      @body_element_index = 2
    end

    # Give up if introduction is to long for vortex.
    if(introduction.size > 1000)then
      @body_element_index = 0
      return ""
    end

    # Clean up html
    introduction = introduction.gsub(/<.?font>/,' ').strip.gsub(/<br>$/,'')

    introduction = remove_special_chars(introduction)
    return introduction
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
    string = Iconv.iconv('ascii//ignore//translit', 'utf-8', string).to_s
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

  def extract_body
    body = @doc.css(".contentpaneopen[2] td").children[@body_element_index..1000].to_s.strip
    body = remove_special_chars(body)
  end

end

if __FILE__ == $0 then
  src_dir = '/Users/thomasfl/workspace/physics_geological_processes/site/varme.uio.no/pgp/'
  webdav_destination = 'https://www-dav.mn.uio.no/konv/pgp/'
  migration = SummerSchoolMigration.new(src_dir,webdav_destination)
  # Optional settings:
  # migration.logfile        = 'pgp_migration_log.txt'
  # migration.errors_logfile = 'pgp_migration_error_log.txt'
  # migration.debug = true
  # migration.dry_run = true
  # migration.migrate_article("index.php?option=com_content&task=view&id=519&Itemid=32.html")
  migration.run
end
