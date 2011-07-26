require '../lib/vortex_static_site_migration'

# Custom code for migrating the joomla site varme.uio.no/pgp site to vortex:
class SummerSchoolMigration < StaticSiteMigration

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

  # Returns filename with path.
  # Ex. /methods/fieldwork/geo-patterns.html
  def extract_filename
    path = "/"

    # Detect the frontpage /corner case
    if(@doc.css("#path>.pathway>.pathway").size > 0 and @doc.css("#path>.pathway>.pathway a").size == 0)then
      return path + "index.html"
    end

    @doc.css("#path>.pathway>.pathway a")[1..100].each do |element|
      path = path + Vortex::StringUtils.create_filename(element.text) + "/"
    end

    # Add last element of breadcrumb to the generated filepath
    breadcrumb_html =  @doc.css("#path>.pathway>.pathway").inner_html
    last_breadcrumb_element = breadcrumb_html[/<img[^>]*>([^<]*)$/,1].strip
    last_breadcrumb_element = Vortex::StringUtils.create_filename(last_breadcrumb_element)
    title = Vortex::StringUtils.create_filename(extract_title.to_s)
    if(not(last_breadcrumb_element == title))
      path = path + last_breadcrumb_element + '/'
    end

    return path + title + ".html"
  end


  def extract_title
    @doc.css(".contentheading").first.text.strip if @doc.css(".contentheading").first
  end

  def extract_introduction
    introduction = ""
    @body_element_index = 0

    @doc.css(".contentpaneopen[2] td").children.each do |element|
      if(element.name == "p")then
        break
      end
      introduction = introduction + element.to_s.strip
      @body_element_index += 1
    end
    introduction = introduction.gsub(/<.?font>/,' ').strip.gsub(/<br>$/,'')
    if(introduction.size > 1000)then
      @body_element_index = 0
      return ""
    end
    if(introduction == "")
      introduction = @doc.css(".contentpaneopen[2] td p[1]").inner_html
      @body_element_index = 2
    end
    return introduction
  end

  def extract_body
    @doc.css(".contentpaneopen[2] td").children[@body_element_index..1000].to_s.strip
  end

end

if __FILE__ == $0 then
  migration = SummerSchoolMigration.new('/Users/thomasfl/workspace/physics_geological_processes/site/varme.uio.no/pgp/',
                                        'https://www-dav.mn.uio.no/konv/pgp/')
  migration.logfile        = 'pgp_migration_log.txt'
  migration.errors_logfile = 'pgp_migration_error_log.txt'
  migration.debug = true
  # migration.encoding = 'ISO-8859-1'
  # migration.dry_run = true

  migration.migrate_article("index.php?option=com_content&task=view&id=519&Itemid=32.html")
  migration.run
end
