# -*- coding: utf-8 -*-
require 'migrate_cancerbiomed.rb'
require 'test/unit'
require 'shoulda'
require 'json'

class MigrateCancerbiomedTest < Test::Unit::TestCase

  def setup
    src  = 'http://www.cancerbiomed.net/'
    dest = 'https://www-dav.vortex-demo.uio.no'
    @dest_path = '/konv/cancerbiomed/'
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

  should "get document tree" do
    @migration.debug = true

    article_url = 'groups/' #     article_url = 'groups/hs/'
    @migration.migrate_article(article_url)

    require 'pp'
    pp @migration.get_children
  end

end;def should(string, &block)end;class DisabledTests

  should "migrate files from same server" do
    @migration.debug = true
    @migration.dry_run = true
    assert @migration.migrate_linked_file?("/file.html")
    assert (not(@migration.migrate_linked_file?("http://www.vg.no/file.html")))
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
    assert @migration.extract_breadcrumb == ["Groups", "Harald Stenmark", "Group Overview"]
  end

end
