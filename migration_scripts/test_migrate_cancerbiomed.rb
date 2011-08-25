# -*- coding: utf-8 -*-
require 'rubygems'
require 'migrate_cancerbiomed.rb'
require 'test/unit'
require 'shoulda'
require 'json'
require 'pry'
require 'pp'

class MigrateCancerbiomedTest < Test::Unit::TestCase

  def setup
    src  = 'http://www.cancerbiomed.net/'
    dest = 'https://www-dav.vortex-demo.uio.no'
    @dest_path = '/konv/test/cancerbiomed/'
    @migration = CancerbiomedMigration.new(src, dest + @dest_path)
    @migration.debug = true
    @migration.logfile        = '/tmp/cancerbiomed_migration_log.txt'
    @migration.errors_logfile = '/tmp/cancerbiomed_migration_error_log.txt'
    @migration.dry_run = false
    @migration.debug = false

    @vortex = @migration.vortex
    @vortex.delete(@dest_path) if @vortex.exists?(@dest_path)
    @vortex.create_path(@dest_path)
  end

  should "scrape the whole page with all images" do
    @migration.debug = true
    @migration.dry_run = false
    @migration.migrate_article('/groups/hs/group-members/')
  end

end;def should(string, &block)end;class DisabledTests

  should "extract introduction if available" do
    @migration.debug = false
    @migration.dry_run = true

    @migration.migrate_article('/groups/hs/')
    assert @migration.extract_introduction.size > 100

    @migration.migrate_article('/groups/hs/key-achievements/')
    assert @migration.extract_introduction.size > 100

    @migration.migrate_article('/groups/hs/projects/')
    assert @migration.extract_introduction == nil

    @migration.migrate_article('/groups/hs/group-members/')
    assert @migration.extract_introduction == nil
  end



  # This take quite long to execute - but really is not necessary if all other tests works
  should "traverse document tree recursively without ending up in infinite recursion" do
    # @migration.debug = true
    # @migration.src_url = "http://www.cancerbiomed.net/groups/hs/"
    # @migration.traverse_tree
    # binding.pry
  end




  should "get document children on all levels" do
    @migration.debug = false # true
    @migration.dry_run = true

    @migration.migrate_article('/groups/')
    assert @migration.get_children == ["/groups/hs/", "/groups/hd/", "/groups/kl/", "/groups/rl/", "/groups/aw/", "/groups/ks/", "/groups/es/"]

    @migration.migrate_article('/groups/hs/publications/')
    assert @migration.get_children == []

    @migration.migrate_article('/groups/hs/')
    assert @migration.get_children == ["/groups/hs/projects/", "/groups/hs/group-members/", "/groups/hs/key-achievements/", "/groups/hs/publications/"]

    article_url = 'groups/hs/projects/'
    @migration.migrate_article(article_url)
    assert @migration.get_children == ["/groups/hs/projects/ucem/", "/groups/hs/projects/psd/", "/groups/hs/projects/cdc/",
                                       "/groups/hs/projects/mapdcd/"]

    @migration.migrate_article('groups/hs/projects/ucem/')
    assert @migration.get_children == [] # Bottom of navigation tree

    @migration.migrate_article('groups/hs/projects/psd/')
    assert @migration.get_children == [] # Another leaf node

    @migration.migrate_article('/')
    assert @migration.get_children == ["/publications", "/groups", "/scientific-programs", "/about-us"]
  end

  should "extract breadcrumbs" do
    @migration.debug = false
    @migration.dry_run = false # true
    article_url = '/groups/hs/projects/ucem/'
    @migration.migrate_article(article_url)

    assert @migration.extract_breadcrumb == ["Groups", "Harald Stenmark", "Projects", "Unit of Cellular Electron Microscopy"]
    props = @vortex.propfind( URI.parse(@migration.dest_url).path + article_url)
    folder_title = props.xpath("//v:collectionTitle", "v" => "vrtx").last.text
    assert folder_title == "Unit of Cellular Electron Microscopy"
  end

  should "extract content from article" do
    @migration.debug = false
    @migration.dry_run = false

    article_url = 'groups/hs/'
    assert (not(@vortex.exists?(@dest_path + article_url + 'index.html')))
    @migration.migrate_article(article_url)
    assert @migration.extract_title == "Harald Stenmark"

    expected_destination = @dest_path + article_url + 'index.html'
    assert @vortex.exists?(expected_destination)
    assert @vortex.exists?(@dest_path + article_url + 'harald_s_group_2010.jpg')
    assert @migration.extract_breadcrumb == ["Groups", "Harald Stenmark"] # , "Group Overview"]

    props = @vortex.propfind( URI.parse(@migration.dest_url).path + '/groups/hs/')
    folder_title = props.xpath("//v:collectionTitle", "v" => "vrtx").last.text
    assert folder_title == "Harald Stenmark"
  end

  should "migrate files from same server" do
    @migration.debug = true
    @migration.dry_run = true
    assert @migration.migrate_linked_file?("/file.html")
    assert (not(@migration.migrate_linked_file?("http://www.vg.no/file.html")))
  end

end
