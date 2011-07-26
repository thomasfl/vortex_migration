require '../lib/vortex_static_site_migration'

# Custom code for migrating the www.stk.uio.no site to vortex:
class SummerSchoolMigration < StaticSiteMigration

  # Migrate all files with .html extension as articles i vortex
  def is_article?(filename)
    return filename[/\.html$/]
  end

  def extract_title
    @doc.css("#mainContent").children.each do |element|
      # Find first non-text element
      if(not(element.name == "text"))then
        if(element.name.to_s[/^h[1..9]/])then
          # First element is a h1,h2... tagg:
          title = element.text
          element.remove
          return title
        else
          # Use last element of breadcrumb instead:
          title = @doc.css("#header>h2").text
          title = title.gsub(/.* :: /,'')
          return title
        end
      end
    end

  end

  def extract_introduction
    first_paragraph = @doc.css("#mainContent>p").first
    intro = ""
    if(first_paragraph)then
      if(first_paragraph.children and first_paragraph.children.first.name = "strong")then
        first_paragraph = first_paragraph.children.first
      end
      intro = first_paragraph.inner_html
      first_paragraph.remove
    end
    return intro
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

  def extract_body
    return @doc.css("#mainContent").first.inner_html
  end

end

migration = SummerSchoolMigration.new('/Users/thomasfl/workspace/iss/site/www.summerschool.uio.no/',
                                      'https://www-dav.vortex-demo.uio.no/konv/iss/')
migration.logfile        = 'summerschool_migration_log.txt'
migration.errors_logfile = 'summerschool_migration_error_log.txt'
# migration.debug = true
migration.run
