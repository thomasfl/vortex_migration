Vortex migration tools
======================

Utitilities for importing static web sites in to the Vortex Content Management System.

## Install ##

## Example ##

First create a local mirror of the website with wget. This should work for most sites, including sites
made with Content Management like WordPress, Joomla, Plone or Drupal.

'''bash
  $ wget --mirror –p --html-extension –-convert-links --force-directories  -e robots=off -P . http://www.summerschool.uio.no/
'''

Use the example scripts that subclasses StaticSiteMigration as documentation.

'''ruby
  puts "Hello"
'''
