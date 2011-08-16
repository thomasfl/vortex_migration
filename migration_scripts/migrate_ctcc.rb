# -*- coding: utf-8 -*-
require '../lib/vortex_static_site_migration'

class CTCCMigration < StaticSiteMigration

  def is_article?(filename)
    filename[/\.html$/]
  end

  def extract_title
    @doc.css(".maintextheading").text
  end

  def extract_introduction
    @doc.css(".maintext p[2]").first.inner_html
  end

  def extract_body
    maintext = @doc.css(".maintext").first
  end

  # Return true if link in html file should be migrated to vortex.
  def migrate_linked_file?(uri)
    host = uri.host.to_s
    path = uri.path.to_s
    if(host == 'www.cma.uio.no')
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
  src_dir = '/tmp/www.ctcc.uio.no'
  webdav_destination = 'https://www-dav.mn.uio.no/konv/cma/'
  migration = CMAMigration.new(src_dir,webdav_destination)
  migration.debug = true
  migration.encoding = "iso-8859-1"
  migration.run

  # migration.transfer_unused_files
  # migration.generate_report
  # migration.generate_migration_html_report
end
