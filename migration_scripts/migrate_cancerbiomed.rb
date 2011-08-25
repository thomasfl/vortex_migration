# -*- coding: utf-8 -*-
require '../lib/vortex_dynamic_site_migration'

# Custom code to migrate the site cancerbiomed.net
class CancerbiomedMigration < VortexDynamicSiteMigration

  def is_article?(url)
    urlfilename[/\.html$/]
  end

  def extract_title
    @doc.css(".subContent h1").first.text.strip
  end

  # Extract intro by removing unwanted elements and returning first elements if h2 tag
  def extract_introduction
    doc = @doc.clone

    doc.css(".subContent h1").first.remove
    doc.css(".subContent .toc-container").remove

    doc.css(".subContent").children.each do|child|
      if(not(child.to_s[/^\s$/m]))
        # puts "child.name:" + child.name
        return child.inner_html if child.name == "h2"
      end
    end
    return nil
  end

  # Extract intro by removing unwanted elements and first element (which is used as introduction)
  def extract_body
    doc = @doc.clone

    # Remove WordPress HighSlide(tm) image-zoom link from images:
    doc.css(".highslide").each do |element|
      element.css("img").first.parent = element.parent
      element.remove
    end

    doc.css(".subContent h1").first.remove
    doc.css(".subContent .toc-container").remove

    # remove introduction
    doc.css(".subContent").children.each do|child|
      if(not(child.to_s[/^\s$/m]))
        child.remove if(child.name == "h2")
        break
      end
    end

    doc.css(".subContent").inner_html ##  p:not(.m2)").to_s
  end

  def extract_filename
    path = URI.parse(@doc_url).path  #TOOD denne variablen er ikke global lenger...
    if(path[/\/$/])
      path = path + "index.html"
    end
    return path.gsub("//","/")
  end

  # Returns breadcrumb as a array of strings
  def extract_breadcrumb
    breadcrumb = []
    breadcrumb << @doc.css(".m1 a.active").text
    @doc.css(".m2 a.active").each do |element|
      breadcrumb << element.text.strip
    end
    # Ignore @doc.css(".m2a a.active").text
    return breadcrumb
  end

  # Helper method
  def extract_href(element)
    URI.parse( element.attr("href") ).path
  end

  # Return list of children as path. Ex. ["/about/","/contact"]
  def get_children
    children = []

    # Return empty list if a level 4 menu element is selected
    return [] if( @doc.css(".toc-container .grandkids .active").any?)

    # Return level 4 menu elements if they are visible
    @doc.css(".toc-container .grandkids a").each do |element|
      children << extract_href(element)
    end
    return children if(children.any?)

    # Return Level 3 selected with no children available
    if(@doc.css(".toc-container .active").any?)
      level_3_selected_path = extract_href(@doc.css(".toc-container .active").first)
      # puts "level_3_selected_path: " + level_3_selected_path

      has_children = true
      @doc.css(".toc-container a").each do |element|
        path = extract_href(element)
        # puts path + " >= " + level_3_selected_path + " ???"
        if(path.split("/").size < level_3_selected_path.split("/").size)
          has_children = false
        end
        if(path != level_3_selected_path)
          children << path
        end
      end

      if(has_children)
        return children
      else
        return []
      end
    end

    # Return level 2 menu elements
    if(@doc.css(".header .m1 .active").any? and @doc.css(".header .m2 .active").none?)
      @doc.css(".header .m2 a").each do |element|
        children << extract_href(element)
      end
      return children
    end

    # Return top level menu elements
    if(@doc.css(".header .m1 .active").none?)
      @doc.css(".header .m1 a").each do |element|
        children << extract_href(element)
      end
      return children
    end

    puts "Error. Can't extract children of document."
    binding.pry
  end

end

if __FILE__ == $0 then
  src  = 'http://www.cancerbiomed.net/'
  dest = 'https://www-dav.vortex-demo.uio.no/konv/cancerbiommed'
  migration = CancerbiomedMigration.new(src, dest)
  migration.debug = true
  # migrate.src_hosts = ["www.cancerbiomed.net"]
  # migration.migrate_article('groups/hs/')
  migration.run
end
