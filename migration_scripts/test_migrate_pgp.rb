# -*- coding: utf-8 -*-
require 'migrate_varme.uio.no_pgp'
require 'test/unit'
require 'shoulda'

class MigratePGPTest < Test::Unit::TestCase

  def setup
    src_dir  = '/Users/thomasfl/workspace/physics_geological_processes/site/varme.uio.no/pgp/'
    @dest_path = '/konv/pgp_test/'
    dest_url = 'https://www-dav.mn.uio.no' + @dest_path
    @migration = PGPMigration.new(src_dir,dest_url)

    @vortex = @migration.vortex
    @vortex.delete(@dest_path) if @vortex.exists?(@dest_path)
    @vortex.create_path(@dest_path)

    @migration.dry_run = false # Do not write to server
    @migration.debug = false   # Do not output debug info
  end

  should "not use first paragraph as intro if it is too long" do
    @migration.dry_run = true
    @migration.migrate_article("index.php?option=com_content&task=view&id=63&Itemid=98.html")
    assert @migration.extract_introduction == ""
  end

  should "extract title and introduction" do
    @migration.dry_run = true
    @migration.migrate_article("index.php?option=com_content&task=view&id=519&Itemid=32.html")
    assert @migration.extract_title == "Vista funding"
    assert @migration.extract_introduction =~ /^VISTA decided/
    assert @migration.extract_body == ""
  end

  should "extract file and pathname" do
    @migration.migrate_article("index.php?option=com_content&task=view&id=604&Itemid=123.html")
    assert @migration.extract_filename =~/^\/people/
    assert @vortex.exists?(@dest_path + 'people/andreas-hafver.html')
    @migration.migrate_article("index.php?option=com_content&task=view&id=90&Itemid=230.html")
    assert @vortex.exists?(@dest_path + 'news/pgp-in-the-news/index.html')
  end

  should "download images" do
    @migration.debug =  true
    @migration.migrate_article("index.php?option=com_content&task=view&id=98&Itemid=32.html")
    binding.pry
  end

  # should "handle encoding"

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
