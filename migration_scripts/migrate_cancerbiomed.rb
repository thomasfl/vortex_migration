# -*- coding: utf-8 -*-
require '../lib/vortex_dynamic_site_migration'
require 'paint'
# Custom code to migrate the site cancerbiomed.net
class CancerbiomedMigration < VortexDynamicSiteMigration

  def isArticle?(path)
    path[/\/$/] if(path)
  end

  def migrate_linked_file?(uri)
    # binding.pry
    return true if(uri.host == "medinfo.net")
    super(uri)
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
        return child.inner_html if child.name == "h2"
      end
    end
    return nil
  end

  # Extract intro by removing unwanted elements and first element (which is used as introduction)
  def extract_body
    doc = @doc.clone

    # Remove WordPress HighSlide(tm) image-zoom javascript link from images:
    doc.css(".highslide").each do |element|
      element.remove_attribute('onclick')
      element.css("span").remove
    end
    doc.css(".highslide-caption").each do |element|
      element.remove
    end

    doc.css(".subContent h1").first.remove
    doc.css(".subContent .toc-container").remove

    # Remove introduction
    doc.css(".subContent").children.each do|child|
      if(not(child.to_s[/^\s$/m]))
        child.remove if(child.name == "h2")
        break
      end
    end

    doc.css(".subContent").inner_html
  end

  def extract_filename(url)
    # path = URI.parse(@doc_url).path  #TOOD denne variablen er ikke global lenger...
    path = URI.parse(url).path  #TOOD denne variablen er ikke global lenger...
    if(path[/\/$/])
      path = path + "index.html"
    end
    return path.gsub("//","/")
  end

  # Returns breadcrumb as an array of strings
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

    # More level 3 corner cases
    if(@doc.css(".header .m2 .active").any? and @doc.css(".toc-container").any?)
      if(@doc.css(".toc-container .m2 .active").none?)
        @doc.css(".toc-container .m2 a").each do |element|
          children << extract_href(element)
        end
        return children if(children.any?)
      end
    end

    # Return level 2 menu elements
    if(@doc.css(".header .m1 .active").any? and @doc.css(".toc-container a").none?) # @doc.css(".header .m2 .active").none?)
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

  # Publications are outside the hierachy, so they need to be migrated separately:
  def migrate_publications
    doc = Nokogiri::HTML(open('http://www.cancerbiomed.net/publications/'))

    doc.css(".subContent h3 > a").each do |link|
      @debug = true

      @doc_url = link.attr("href")
      begin
        @doc = Nokogiri::HTML(open(@doc_url))
      rescue => e
        puts "Error: " + e.inspect + ": " + @doc_url
        # binding.pry
        return
      end

      title = extract_title
      introduction = extract_introduction
      body = extract_body
      related = extract_related_content

      new_filename = URI.parse(link.attr("href")).path + "index.html"
      path = URI.parse(@dest_url).path + URI.parse(link.attr("href")).path

      # publish_article(new_filename, title, introduction, related, body)
      # @vortex.proppatch(path, '<hidden xmlns="http://www.uio.no/navigation">true</hidden>')
      # @vortex.proppatch(path, '<v:userTitle xmlns:v="vrtx">' + title + '</v:userTitle>')
      # puts Paint["Published   : ", :green, :bright] + new_filename
      # puts Paint["Proppatched : ", :green, :bright] + path

      # binding.pry
###      link.set_attribute("href", ".." + URI.parse(@doc_url).path )
    end

    new_filename = "/publications/index.html"
    title = "Publications"
    introduction = nil
    related = nil

    body = doc.css(".subContent > ul").inner_html
    publish_article(new_filename, title, introduction, related, body)
  end

end

if __FILE__ == $0 then
  # src = 'http://www.cancerbiomed.net/groups/' # groups/hd/projects/'
  # src = 'http://www.cancerbiomed.net/scientific-programs/'

  # src = 'http://www.cancerbiomed.net/scientific-programs/cell-signalling-in-cancer/'
  # src = 'http://www.cancerbiomed.net/scientific-programs/genomics-epigenomics/'
  # src = 'http://www.cancerbiomed.net/scientific-programs/novel-imaging-tools/'
  # src = 'http://www.cancerbiomed.net/about-us/'

  src = 'http://www.cancerbiomed.net/publications/'
  dest = 'https://www-dav.vortex-demo.uio.no/konv/cancerbiomed'
  migration = CancerbiomedMigration.new(src, dest)
  migration.debug = true

  migration.migrate_publications()

  # migrate.src_hosts = ["www.cancerbiomed.net"]
  # migration.migrate_article('groups/hs/')
  # migration.run
end
