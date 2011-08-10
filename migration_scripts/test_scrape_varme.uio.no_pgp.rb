# -*- coding: utf-8 -*-
require 'scrape_varme.uio.no_pgp'
require 'test/unit'
require 'shoulda'

class MigratePGPTest < Test::Unit::TestCase

  def setup
    src_dir  = '/Users/thomasfl/workspace/physics_geological_processes/site/varme.uio.no/pgp/'
    @dest_path = '/konv/pgp_test/'
    dest_url = 'https://www-dav.mn.uio.no' + @dest_path
    @migration = PGPMigration.new(src_dir,dest_url)
    @migration.dry_run = true
    @migration.logfile        = 'pgp_migration_log.txt'
    @migration.errors_logfile = 'pgp_migration_error_log.txt'
    @migration.debug = true

    @vortex = @migration.vortex
    @vortex.delete(@dest_path) if @vortex.exists?(@dest_path)
    @vortex.create_path(@dest_path)

    @migration.dry_run = false
    @migration.debug = false
  end


  should "extract title and introduction" do
    @migration.debug = false
    @migration.dry_run = true
    @migration.migrate_article("index.php?option=com_content&task=view&id=519&Itemid=32.html")
    assert @migration.extract_title == "Vista funding"
    assert @migration.extract_introduction =~ /^VISTA decided/
    assert @migration.extract_body == ""
    # binding.pry
  end


end;def should(string, &block)end;class DisabledTests

  def test_crash2
    @migration.dry_run = false
    @migration.migrate_article("index.php?option=com_content&task=view&id=581&Itemid=32.html")
    # @migration.migrate_article("index.php?option=com_content&task=view&id=27&Itemid=32.html")
  end

  def test_chrash
    @migration.dry_run = false
    @migration.migrate_article("/tmp/pgp/varme.uio.no/pgp/index.php?option=com_content&task=view&id=496&Itemid=68.html")
  end

  def test_duplicate_content
    @migration.vortex.delete("/konv/pgp_test/home/about-pgp/about-pgp-physics-of-geological-processes-geologiske-prosessers-fysikk.html")
    @migration.dry_run = false
    @migration.migrate_article("index.php?option=com_content&task=view&id=14&Itemid=243.html")

    # puts "Title : " + @migration.extract_title
    # puts "-------"
    # puts "Intro : " + @migration.extract_introduction
    # puts "-------"
    puts @migration.extract_body
  end


  def zzz_test_too_long_intro
    # First paragraph is to long to be used as intro
    @migration.debug = false
    @migration.migrate_article("index.php?option=com_content&task=view&id=63&Itemid=98.html")
    assert @migration.extract_introduction == ""
  end

  def test_extract_filepath
    # @migration.debug = false # true
    @migration.migrate_article("index.php?option=com_content&task=view&id=604&Itemid=123.html")
    assert @migration.extract_filename =~/^\/people/
    # puts @migration.extract_filename

    @migration.debug = true
    @migration.dry_run = false
    @migration.migrate_article("index.php?option=com_content&task=view&id=90&Itemid=230.html")
  end

  # Manual test to test unicode conversion and article-image
  def test_upload_images
    # @migration.debug =  false
    @migration.dry_run = false
    # @migration.encoding = 'ISO-8859-1'
    @migration.migrate_article("index.php?option=com_content&task=view&id=98&Itemid=32.html")
    # @migration.dry_run = true
  end

  def test_crashing_articles
    # @migration.debug =   false
    @migration.dry_run = true
    @migration.migrate_article("index.php?option=com_content&task=view&id=525&Itemid=32.html")
    # @migration.debug =   true
    @migration.dry_run = false
    @migration.migrate_article("index.php?option=com_content&task=view&id=352&Itemid=360&limit=1&limitstart=1.html")
  end

  def test_missing_path
    # @migration.debug =   true
    @migration.dry_run = false
    @migration.migrate_article("index.php?option=com_content&task=view&id=77&Itemid=123.html")
  end

  # Each page is download 4 times by 'wget'. Make sure the right ones is used:
  def test_avoid_duplicates
    # @migration.debug =   true
    @migration.dry_run = true

    @migration.is_article?(@migration.html_dir + "index.php?option=com_content&task=view&id=111&Itemid=32.html") == true
    @migration.is_article?(@migration.html_dir + "index.php?option=com_content&task=view&id=111&Itemid=300.html") == false
    # @migration.is_article?(@migration.html_dir + "index2.php?option=com_content&task=view&id=111&pop=1&page=0&Itemid=300.html") == false
    # @migration.is_article?(@migration.html_dir + "index2.php?option=com_content&task=view&id=111&pop=1&page=0&Itemid=32.html") == false
  end

end
