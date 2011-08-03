# -*- coding: utf-8 -*-
require 'rubygems'
require 'find'
require 'pathname'
require 'nokogiri'
require 'vortex_client'
require 'json'
require 'open-uri'

@webdav_destination = 'https://www-dav.mn.uio.no/konv/pgp'
@vortex = Vortex::Connection.new(@webdav_destination, :osx_keychain => true)
@renamed_folders = { }

def rename_folder(path,folder_title)
  if(!@renamed_folders[path])
    @renamed_folders[path] = folder_title
    folder_to_rename = @webdav_destination + path
    folder_title = folder_title.gsub("&", "&amp;")
    puts "Renaming: '#{folder_to_rename}' => '#{folder_title}'"
    @vortex.proppatch(folder_to_rename, '<v:userTitle xmlns:v="vrtx">' +
                      folder_title + '</v:userTitle>')
  end
end

def set_folder_titles(path,breadcrumb)
  breadcrumbs_array = breadcrumb.split(";")
  folder_to_rename = ""
  index = 0
  path.split("/").each do |path_element|
    if(path_element != "")
      folder_to_rename = folder_to_rename + "/" + path_element
      folder_title = breadcrumbs_array[index].strip
      rename_folder(folder_to_rename,folder_title)
      index += 1
    end
  end
end

def parse_breadcrumb_file(filename)
  # index = 0
  breadcrumbs_file = open(filename).read
  breadcrumbs_file.each do |line|
    path, breadcrumb = line.split(':')
    set_folder_titles(path,breadcrumb)
    # index += 1
    # exit if(index > 0)
  end
end

logfile = "varme.uio.no_pgp_breadcrumbs.sorted.log" # NB Denne filen er kjørt gjennom 'sort'!!
parse_breadcrumb_file(logfile)
