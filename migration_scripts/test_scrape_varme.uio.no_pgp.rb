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

    # @migration.vortex.delete("/konv/pgp/")
    # @migration.vortex.create_path("/konv/pgp/")
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

  # Manual test to test unicode conversion and article-image
  def zzz_test_upload_images
    @migration.debug =  false
    @migration.dry_run = false
    # @migration.encoding = 'ISO-8859-1'
    @migration.migrate_article("index.php?option=com_content&task=view&id=98&Itemid=32.html")
    # @migration.dry_run = true
  end

  def zzz_test_crashing_articles
    @migration.debug =   false
    @migration.dry_run = true
    @migration.migrate_article("index.php?option=com_content&task=view&id=525&Itemid=32.html")
    @migration.debug =   true
    @migration.dry_run = false
    @migration.migrate_article("index.php?option=com_content&task=view&id=352&Itemid=360&limit=1&limitstart=1.html")
  end

  def test_missing_path
    @migration.debug =   true
    @migration.dry_run = false
    @migration.migrate_article("index.php?option=com_content&task=view&id=77&Itemid=123.html")

  end

end
