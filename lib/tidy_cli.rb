require 'rubygems'
require 'nokogiri'

ugly = Nokogiri::HTML ARGF
tidy = Nokogiri::XSLT File.open(File.dirname(__FILE__) + '/tidy.xsl')
nice = tidy.transform(ugly).to_html

puts nice
