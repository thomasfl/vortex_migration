# -*- coding: utf-8 -*-
require 'migrate_cma.uio.no.rb'
require 'test/unit'
require 'shoulda'
require 'json'

class MigrateCMATest < Test::Unit::TestCase

  def setup
    src_dir = '/tmp/www.cma.uio.no'
    @dest_path = '/konv/cma_test/'
    dest_url = 'https://www-dav.mn.uio.no' + @dest_path
    @migration = CMAMigration.new(src_dir,dest_url)
    @migration.encoding = "iso-8859-1"

    @migration.logfile        = '/tmp/cma_migration_log.txt'
    @migration.errors_logfile = '/tmp/cma_migration_error_log.txt'

    @vortex = @migration.vortex
    @vortex.delete(@dest_path) if @vortex.exists?(@dest_path)
    @vortex.create_path(@dest_path)

    @migration.dry_run = false
    @migration.debug = false
  end

  should "extract title" do
    # @migration.dry_run = true
    @migration.debug = true

    article_file = 'openpositions/index.html'
    @migration.migrate_article(article_file)
    assert @migration.extract_title == "OPEN POSITIONS"

    article_file = 'researchplan/goals.html'
    @migration.migrate_article(article_file)
    puts "title: '" + @migration.extract_title + "'"

  end

# end;def should(string, &block)end;class DisabledTests

  should "not migrate graphic decorations" do
    # @migration.debug = true
    article_file = 'openpositions/index.html'
    @migration.migrate_article(article_file)
    assert (not(@vortex.exists?(@dest_path + 'openpositions/illustrasjon1.jpg')))
    # binding.pry
  end

  should "migrate pictures in person presentations" do
    article_file = 'people/person/snorrechristiansen.html'
    @migration.migrate_article(article_file)
    assert @vortex.exists?(@dest_path + 'people/person/snorrechristiansen.jpg')

    article_file = 'people/person/torsteinnilssen.html'
    @migration.migrate_article(article_file)
  end


  should "handle redirects in html head" do
    # @migration.debug = true
    article_file = 'conferences/2009/ragnar60.html'
    @migration.migrate_article(article_file)
    assert (not(@vortex.exists?(@dest_path + article_file)))

    article_file = 'conferences/2009/winther60.html'
    @migration.migrate_article(article_file)
    assert @vortex.exists?(@dest_path + article_file)
  end

  should "migrate images in local folder" do
    # @migration.debug = false
    article_file = 'conferences/2004/subdivision_participants.html'
    @migration.migrate_article(article_file)
    @vortex.exists?(@dest_path + 'conferences/2004/linje.gif')
  end

  should "handle links to anchors" do
    # @migration.debug = true
    article_file = 'reports/publications/index2008.html'
    @migration.migrate_article(article_file)
    # binding.pry
    content = JSON.parse(@vortex.get(@dest_path + article_file))["properties"]["content"]
    assert content.match("href=\"#books") ## ")[/href=\"#books/]
  end

  should "handle unparseable links in html" do
    # @migration.debug = false
    @migration.migrate_article('seminars/old/2005CMAseminar.html')
    @vortex.exists?(@dest_path + 'seminars/old/2005CMAseminar.html')

    @migration.migrate_article('projects/collaborative/cse_kurs.html')
    assert @vortex.exists?(@dest_path + 'projects/collaborative/cse_kurs.html')
  end

  should "handle missing pictures" do
    @migration.migrate_article('conferences/2005/imageprocessing_workshop.html')
    assert @vortex.exists?(@dest_path + 'conferences/2005/imageprocessing_program.pdf')
    assert @vortex.exists?(@dest_path + 'conferences/2005/imageprocessing_workshop.html')
  end

  should "not download pdf files from external server" do
    article_file = 'seminars/old/2009stochastic_analysis.html'
    @migration.migrate_article(article_file)
    content = JSON.parse(@vortex.get(@dest_path + article_file))["properties"]["content"]
    assert content[/href=\"http:\/\/folk.uio.no\/jlempa/]
  end

  should "Publish a file" do
    assert (not(@vortex.exists?(@dest_path + 'aboutcma.html')))
    @migration.migrate_article('aboutcma.html')
    assert @migration.extract_title == 'About CMA'
    assert @vortex.exists?(@dest_path + 'aboutcma.html')
  end

  should "Convert norwegian characters from iso-8859-1 to utf-8" do
    @migration.migrate_article('people/fellows.html')
    assert @vortex.exists?(@dest_path + 'people/fellows.html')
    content = JSON.parse(@vortex.get(@dest_path + 'people/fellows.html'))["properties"]["content"]
    assert content[/Håkon Dahle/]
  end

  should "Handle missing introductions" do
    @migration.migrate_article('seminars/old/2010CMAjournalclub.html')
    assert @vortex.exists?(@dest_path + 'seminars/old/2010CMAjournalclub.html')
  end

end
