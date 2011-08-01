Vortex migration tools
======================

Utitilities for importing static web sites in to the Vortex Content Management System.

## Install ##

## Example ##

First create a local mirror of the website with wget. This should work for most sites, including sites
made with Content Management like WordPress, Joomla, Plone or Drupal.

```bash
  $ wget --mirror –p --html-extension –-convert-links --force-directories  -e robots=off -P . http://www.summerschool.uio.no/
```
Create a subclasses of StaticSiteMigration as documentation.

```ruby
require '../lib/vortex_static_site_migration'

class SummerSchoolMigration < StaticSiteMigration

  def is_article?(filename)
    filename[/index.php.*\.html$/]
  end

  def extract_title
    @doc.css(".contentheading").first.text.strip
  end

  def extract_introduction
    @doc.css(".content").children[0..1].to_s.strip
  end

  def extract_body
    return @doc.css(".content").children[2..1000].to_s.strip
  end

end

if __FILE__ == $0 then
  src_dir = '/Users/thomasfl/workspace/physics_geological_processes/site/varme.uio.no/pgp/'
  webdav_destination = 'https://www-dav.mn.uio.no/konv/pgp/'
  migration = SummerSchoolMigration.new(src_dir,webdav_destination)
  # Optional settings:
  # migration.logfile        = 'pgp_migration_log.txt'
  # migration.errors_logfile = 'pgp_migration_error_log.txt'
  # migration.debug = true
  # migration.dry_run = true
  # migration.migrate_article("index.php?option=com_content&task=view&id=519&Itemid=32.html")
  migration.run
end

```
