# -*- coding: utf-8 -*-
require '../lib/vortex_static_site_migration'

class CMAMigration < StaticSiteMigration

  def is_article?(filename)
    filename[/\.html$/]
  end

  def extract_title
    @doc.css(".maintextheading").text
  end

  def extract_introduction
    intro = @doc.css(".maintext p[2]").first
    if(intro)
      return intro.inner_html
    else
      return ""
    end
  end

  def extract_body
    maintext = @doc.css(".maintext").first
    if(not(maintext))
      return ""
    end
    body = maintext.children[5..100].to_s
    next_element = maintext.next
    while(next_element)
      # Remove graphic design elements
      next_element.css("img").each do |img_element|
        if(img_element.attr("src")[/illustrasjon/])
          img_element.remove
        end
      end
      body = body + next_element.to_s
      next_element = next_element.next
    end
    return body
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

if __FILE__ == $0 then
  # system("cd /tmp;wget --mirror –p --html-extension –-convert-links --force-directories  -e robots=off -P . http://www.cma.uio.no/index.html")
  src_dir = '/tmp/www.cma.uio.no'
  webdav_destination = 'https://www-dav.mn.uio.no/konv/cma/'
  migration = CMAMigration.new(src_dir,webdav_destination)
  migration.debug = true
  migration.encoding = "iso-8859-1"
  migration.run

  # migration.transfer_unused_files
  # migration.generate_report
  # migration.generate_migration_html_report

end
