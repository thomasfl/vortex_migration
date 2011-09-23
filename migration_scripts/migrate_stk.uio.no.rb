# -*- coding: iso-8859-1 -*-
require '../lib/vortex_static_site_migration'

# Custom code for migrating the www.stk.uio.no site to vortex:
class STKMigration < StaticSiteMigration

  # Migrate all files with .html extension as articles i vortex
  def is_article?(filename)
    return filename[/\.html$/]
  end

  def extract_published_date
    @doc.css("meta").each do |meta|
      if meta.attr("name").eql?("dato.opprettet")
        return convert_date(meta.attr("content"))
        # published_date = format_date(meta.attr("content"))
        # puts "published_date: " + published_date.to_s
        # binding.pry
      end
    end
  end

  def extract_title
    @doc.css("head title").first.inner_html
  end

  def extract_introduction
    if @doc.css('table[width="70%"] table[width="100%"] td')
      introduction = @doc.css('table[width="70%"] table[width="100%"] td').inner_html
      @doc.css('table[width="70%"] table[width="100%"]').remove
    elsif @doc.css('table[width="90%"] td[width="80%"] td')
      introduction = @doc.css('table[width="90%"] td[width="80%"] td').inner_html
    end
    introduction = introduction.gsub(/<\/?h[^>]*>/,"").strip #removes h1-,h2-,h3- and hr-formatting
    introduction = introduction.gsub(/\s{2,}/,' ').gsub(/\s{2,}/,' ') #removes two or more adherent spaces
#binding.pry
    return introduction
  end

  def extract_related_content
    related_content = @doc.css("#sidebar2").first
    if(related_content)
      related_content.css("img").remove
      related_content.children.each do |child|
        child.remove if child.comment?
      end
      related_content = related_content.inner_html.sub(/^(<br>)*/,'')
      if(related_content == "")then
        return nil
      end
      return related_content
    end
    return nil
  end

  def migrate_linked_file?(uri)
    if(uri.to_s[/^http/])
       return uri.host == "www.stk.uio.no"
     else
       return File.exists?(uri.to_s)
     end
  end

  def extract_body
    content = ""
    @doc.css('table[width="70%"] td').each do |td|
      content =  content + td.inner_html.to_s
    end
    # content = content.gsub(/\<!--.*\-->/,'').gsub(/\<!--\n.*\-->/,'')       #removes comments
    content = content.gsub(/\s{2,}/,' ').gsub(/\s{2,}/,' ') #removes two or more adherent spaces
    content = content.gsub(/style=\"[^\"]*\"/,"")  #removes inline style
    content = content.gsub(/<\/?font[^>]*>/,"") #removes font-formatting
    content = content.gsub(/"/,"'").gsub("\n","").gsub("\r","").gsub("ó","o")
    return content
  end

private

  def convert_date(date)
    p=date.split("-")
    begin
      time = Time.local(p[0],p[2],p[1])
    rescue
      begin
        time = Time.local(p[0],p[1],p[2])
      rescue
        time = nil
      end
    end

    return time
  end

end

if __FILE__ == $0 then
  src  = "/tmp/www.stk.uio.no/formidling/"
  dest = 'https://nyweb5-dav.uio.no/konv/migrert/'
  migration = STKMigration.new(src, dest )

  migration.logfile        = 'stk_migration_log.txt'
  migration.errors_logfile = 'stk_migration_error_log.txt'
  # migration.debug = true
  migration.run
end
