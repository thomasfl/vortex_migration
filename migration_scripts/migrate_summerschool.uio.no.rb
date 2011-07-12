require '../lib/vortex_static_site_migration'

# Custom code for migrating the www.summerschool.uio.no site vortex:
class SummerSchoolMigration < StaticSiteMigration

  # Migrate all files with .html extension as articles i vortex
  def is_article?(filename)
    return filename[/\.html$/]
  end

  def extract_title
    title_element = @doc.css("#mainContent>h3").first
    title = ""
    if(title_element)then
      title = title_element.text
      title_element.remove # Remove title from body
    else
      title = @doc.css("#header>h2").text
      title = title.gsub(/.* :: /,'')
    end
    return title
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

  def extract_body
    return @doc.css("#mainContent").first.inner_html
  end

  def post_process_publish
  end
end


# Only run if invoked as a script:
if $0 == __FILE__
  migration = SummerSchoolMigration.new('/Users/thomasfl/workspace/iss/site/www.summerschool.uio.no/',
                                        'https://www-dav.vortex-demo.uio.no/konv/iss/')
  migration.logfile        = 'summerschool_migration_log.txt'
  migration.errors_logfile = 'summerschool_migration_error_log.txt'
  migration.debug = true

  migration.generate_report


  # migration.migrate_article('courses/index.html')
  # migration.migrate_article('courses/pds.html')
  # migration.migrate_article('highlights/staff.html')
  # migration.migrate_article('test/language.html')
  # migration.migrate_article('admission/graduate_requirements.html') # <strong>Intro
  # migration.start
end

