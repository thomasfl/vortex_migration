require 'rubygems'
require 'nokogiri'


def tidy_html(html)
  ugly = Nokogiri::HTML.parse(html)
  tidy = Nokogiri::XSLT(File.open(File.dirname(__FILE__) + '/tidy.xsl'))
  return tidy.transform(ugly).to_html
end
