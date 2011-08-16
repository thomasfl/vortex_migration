# -*- coding: utf-8 -*-
require '../lib/vortex_static_site_migration'

# Migrate site by scraping from site. Used when it is not possible to
# get a local copy of the sites html files.
class DynamicSiteMigration

  attr_accessor :debug, :logfile, :errors_logfile, :dry_run, :encoding, :vortex, :html_dir, :src_url, :dest_url

  def initialize(src,dest)
    @src_url = src
    @dest_url = dest
    @document_count = 0
  end

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
    puts "src:" + @doc_url
    @doc = Nokogiri::HTML(open(@doc_url))
    title = extract_title
    introduction = extract_introduction
    body = extract_body
    related = extract_related_content

    filename = extract_filename

    if(@debug)
      puts "Count     : " + @document_count.to_s
      @document_count = @document_count + 1
      puts "Title     : " + title.to_s
      puts "Intro     : " + introduction.to_s #[0..140]
      puts "Related   : " + related.to_s[0..140] if(related and related.to_s != "")
      puts "Body      : " + body.to_s[0..140]
      # puts "Filename  : " + new_filename if(new_filename != "")
    end


  end

  # Run complete migration
  def run
  end

end

# Custom code to migrate the site www.ctcc.uio.no
class CTCCMigration < DynamicSiteMigration # StaticSiteMigration

  def is_article?(filename)
    filename[/\.html$/]
  end

  def extract_title
    @doc.css(".documentFirstHeading").first.text
  end

  def extract_introduction
    if(@doc.css(".plain td").first)
      return @doc.css(".plain td").first.inner_html
    elsif(@doc.css(".plain p").first)
      return @doc.css(".plain p").first.inner_html
    else
      return @doc.css(".plain").first.inner_html
    end
  end

  def extract_body
    if(@doc.css(".plain td").size > 1)
      return @doc.css(".plain td")[1..1000].inner_html
    elsif(@doc.css(".plain p").size > 1)
      return @doc.css(".plain p")[1..1000].inner_html
    else
      return ""
    end
    # binding.pry
    # @doc.css(".plain p").first.inner_html
    # @doc.css(".plain td")[1..100].inner_html
  end

  def extract_breadcrumb
    breadcrumb = []
    @doc.css("#portal-breadcrumbs a").each do |element|
      breadcrumb << element.text
    end
    breadcrumb << @doc.css("#portal-breadcrumbs span").last.text
    # binding.pry
    return breadcrumb[1..1000]
  end

  # Return true if link in html file should be migrated to vortex.
  def migrate_linked_file?(uri)
    host = uri.host.to_s
    path = uri.path.to_s
    if(host == 'www.ctcc.uio.no')
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

end

# Only run when invoced as a script to make it testable
if __FILE__ == $0 then
  # system("cd /tmp;wget --mirror –p --html-extension –-convert-links --force-directories  -e robots=off -P . http://www.ctcc.uio.no/index.html")
  # src_dir = '/tmp/www.ctcc.uio.no/' # Bare migrer alt under "CTCC" i hovedmenyen.
  # webdav_destination = 'https://www-dav.mn.uio.no/konv/cma/'
  src_dir = 'http://www.ctcc.uio.no/'
  webdav_destination = 'https://www-dav.vortex-demo.uio.no/konv/ctcc/' # For utvikling og test
  migration = CTCCMigration.new(src_dir,webdav_destination)
  migration.debug = true
  # migration.migrate_article('people/ruud/kenneth-ruud/index.html')

  migration.migrate_article('ctcc/board-of-directors')

  # migration.encoding = "iso-8859-1" # utf-8 er default
  # migration.run

  # migration.transfer_unused_files
  # migration.generate_report
  # migration.generate_migration_html_report
end
