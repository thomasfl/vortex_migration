# -*- coding: utf-8 -*-
require 'scrape_varme.uio.no_pgp'
require 'test/unit'

class LinkFixerTest < Test::Unit::TestCase

  def setup
    @migration = SummerSchoolMigration.new('/Users/thomasfl/workspace/physics_geological_processes/site/varme.uio.no/pgp/',
                                      'https://www-dav.mn.uio.no/konv/pgp/')
    @migration.dry_run = true
    @migration.logfile        = 'pgp_migration_log.txt'
    @migration.errors_logfile = 'pgp_migration_error_log.txt'

  end

  def zzz_test_title
    # First, and only, paragaph should be used as introduction
    @migration.debug = false
    @migration.migrate_article("index.php?option=com_content&task=view&id=519&Itemid=32.html")
    assert @migration.extract_title == "Vista funding"
    assert @migration.extract_introduction =~ /^VISTA decided/
    assert @migration.extract_body == ""
  end

  def zzz_test_too_long_intro
    # First paragraph is to long to be used as intro
    @migration.debug = false
    @migration.migrate_article("index.php?option=com_content&task=view&id=63&Itemid=98.html")
    assert @migration.extract_introduction == ""
  end

  def extract_filepath
    @migration.debug = false # true
    @migration.migrate_article("index.php?option=com_content&task=view&id=604&Itemid=123.html")
    assert @migration.extract_filename =~/^\/people/
    # puts @migration.extract_filename

    @migration.debug = true
    @migration.migrate_article("index.php?option=com_content&task=view&id=90&Itemid=230.html")
  end

  def test_upload_images
    @migration.debug =  true
    @migration.dry_run = false
    @migration.encoding = 'ISO-8859-1'
    @migration.migrate_article("index.php?option=com_content&task=view&id=98&Itemid=32.html")

    @migration.dry_run = true
  end

end
