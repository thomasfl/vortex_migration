# -*- coding: utf-8 -*-
require '../lib/vortex_static_site_migration'

class CMAMigration < StaticSiteMigration

  def is_article?(filename)
    filename[/\.html$/]
  end

#  def pre_publish(destination_filename, data)
#    @extracted_title = nil
#  end

  def extract_title
    # Make it possible to call this method more than 1 time for testing
    # if(@extracted_title)
    #  return @extracted_title
    #end

    if(@doc.css(".maintextheading").first)
      title = @doc.css(".maintextheading").first
    elsif(@doc.css(".maintextheadingsmall").first)
      title = @doc.css(".maintextheadingsmall").first
    end
    if(title)
      @extracted_title = title.text
      # title.remove
      return @extracted_title
    end
    return nil
  end

  def extract_introduction
    # Since we don't migrate css, add style attributes.
    @doc.css(".maintextheadingsmall").each do |element|
      element["style"] = "font-weight: bold;font-size: 1.1em;"
    end
    @doc.css(".maintextheading").each do |element|
      element["style"] = "font-weight: bold;font-size: 1.2em;"
    end
    @doc.css("style2").each do |element|
      element["style"] = "font-weight: bold;"
    end

    intro = @doc.css(".maintext p[2]").first
    if(intro)
      return intro.inner_html
    else
      if(@doc.css(".maintext dt").first)
        return @doc.css(".maintext dt").first.inner_html
      end
    end
    return ""
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
        if(img_element.attr("src")[/illustrasjon|004/])
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
