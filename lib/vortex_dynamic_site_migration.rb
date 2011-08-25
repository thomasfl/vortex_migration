require File.expand_path "../vortex_site_migration", __FILE__

# Migrate site by scraping from site. Used when it is not possible to
# get a local copy of the sites html files.
class VortexDynamicSiteMigration < VortexSiteMigration

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

  # Sets folder title from breadrcrumb
  def update_breadcrumbs(current_folder_path, breadcrumbs)
    folders = current_folder_path.split("/").reverse
    index = 0
    breadcrumbs.reverse.each do |breadcrumb_element|
      folder = folders[index..1000].reverse.join("/")
      # puts folder + " => " +  breadcrumb_element
      props =  @vortex.propfind(folder)
      old_folder_title = props.xpath("//v:collectionTitle", "v" => "vrtx").last.text
      new_folder_title = breadcrumb_element.gsub("&","and")
      if(old_folder_title != new_folder_title)
        begin
          @vortex.proppatch( folder, '<v:userTitle xmlns:v="vrtx">' + new_folder_title + '</v:userTitle>')
        rescue
          puts "Error while proppatching :" + folder + '=> <v:userTitle xmlns:v="vrtx">' + new_folder_title + '</v:userTitle>'
          binding.pry
        end
      end

      index += 1
    end
  end

  def migrate_article(url)
    @doc_url = @src_url + url
    @doc = Nokogiri::HTML(open(@doc_url))
    title = extract_title
    introduction = extract_introduction
    body = extract_body
    related = extract_related_content

    new_filename = extract_filename
    destination = @dest_url
    destination = destination + new_filename if(new_filename != "")

    if(@debug)
      puts "Count     : " + @document_count.to_s
      @document_count = @document_count + 1
      puts "Title     : " + title.to_s
      puts "Intro     : " + introduction.to_s #[0..140]
      puts "Related   : " + related.to_s[0..140] if(related and related.to_s != "")
      puts "Body      : " + body.to_s[0..140]
      puts "Filename  : " + new_filename if(new_filename != "")
      puts "Dest.     : " + destination
    end

    if(not(@dry_run))then
      publish_article(new_filename, title, introduction, related, body)

      breadrcumb = extract_breadcrumb
      current_folder_path = Pathname.new(URI.parse(destination).path).parent.to_s.gsub("//","/")
      if(breadrcumb)
        update_breadcrumbs(current_folder_path, breadrcumb)
      end

    end
    if(@debug)
      width, height = detect_terminal_size
      width = 80 if(not(width))
      puts "_" * width
    end

  end

  # Same as "start"
  def traverse_tree
    # binding.pry
    migrate_article("")
    migrate_children(get_children)
  end

  def migrate_children(children)
    children.each do |child|
      src_path = URI.parse(@src_url).path
      child_path = child.sub(src_path, "").sub(/^\//,'')
      migrate_article( child_path )
      children = get_children
      migrate_children(children)
    end
  end

  def get_children
    return nil
  end

  # Run complete migration
  def run
    traverse_tree
  end

end
