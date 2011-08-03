# -*- coding: utf-8 -*-
require 'vortex_static_site_migration'

class StaticSiteMigration

  # Generate report
  def generate_report
    report_data = collect_report_data
    uploaded_files = report_data['uploaded_files']
    local_files = report_data['local_files']
    extensions = report_data['extensions']
    file_type_counts = report_data['file_type_counts']
    unpublished_files = report_data['unpublished_files']
    unpublished_files_extensions = report_data['unpublished_files_extensions']

    # Print report
    puts "Vortex migreringsrapport"
    puts "========================"
    puts
    puts "Dokumenter lagt i Vortex på " + @url.gsub('www-dav','www').gsub(/^https/,'http') + ":"
    puts

    total_type_count = 0
    file_type_counts.keys.each do |filetype|
      type_count = file_type_counts[filetype]
      total_type_count = total_type_count + type_count
      puts "  " + filetype.capitalize.ljust(20) + " :" + type_count.to_s.rjust(6)
    end
    puts "  " + ("-" * 28)
    puts "  " + "Totalt".ljust(20) + " :" +  total_type_count.to_s.rjust(6)
    puts

    puts "Filer lagt i Vortex:"
    print_file_count_size(extensions)
    puts

    puts "Upubliserte filer:"
    print_file_count_size(unpublished_files_extensions)
    puts

    puts "Upubliserte filer:"
    puts "  " + unpublished_files.join("\n  ")
    puts

  end

  def generate_migration_html_report
    filename = @vortex_path + 'nettpublisering/rapporter/migration_report.html'
    puts "Publishing migration report : " + filename

    report_data = collect_report_data
    uploaded_files = report_data['uploaded_files']
    local_files = report_data['local_files']
    extensions = report_data['extensions']
    file_type_counts = report_data['file_type_counts']
    unpublished_files = report_data['unpublished_files']
    unpublished_files_extensions = report_data['unpublished_files_extensions']

    body = "<h2>Migrert innhold</h2>\n"
    body += "<p>Dokumenter lagt i Vortex på #{@url.gsub('www-dav','www').gsub(/^https/,'http')}.</p>\n"
    body += "<table>\n"
    total_type_count = 0
    file_type_counts.keys.each do |filetype|
      type_count = file_type_counts[filetype]
      total_type_count = total_type_count + type_count
      body += "  <tr>\n"
      body += "    <td>#{filetype.capitalize}s</td><td align=\"right\">#{type_count.to_s}</td>\n"
      body += "  </tr>\n"
    end
    body += "<tr>\n    <td><b>Total</b></td><td align=\"right\"><b>#{total_type_count.to_s}</b></td>\n  </tr>\n</table>\n"

    body += "<p>\nFiler lagt i Vortex:#{generate_file_count_size_html(extensions)}\n"
    body += "</p>"

    body += "<h2>Ikke migrert innhold</h2>\n"
    body += "<p>\nFiler lagt i folderen <a href=\"../ikke_migrert_innhold\">ikke migrert innhold</a>;\n"
    body += generate_file_count_size_html(unpublished_files_extensions)
    body += "</p>"

    body += "<p>Ikke migrerte filer:\n  <ul>\n"
    unpublished_files.each do |unpublished_file|
      file_path = URI.parse(@url).path + "nettpublisering/ikke_migrert_innhold/" +
        Pathname.new(unpublished_file).parent.to_s.downcase + '/' +
        Pathname.new(unpublished_file).basename.to_s

      body += "    <li><a href=\"" +  file_path +  "\">" + unpublished_file + "</li>\n"
    end
    body += "  </ul>\n</p>"


    t = Time.now
    data = {
      "resourcetype" => "structured-article",
      "properties" =>    {
        "title" => "Migreringsrapport",
        "content" => body,
        "introduction" => "Nettstedet ble migrert fra et statisk nettsted " + t.strftime("%d.%m.%Y kl. %H:%m") + ".",
        "hideAdditionalContentEvent" => "true"
      }
    }

    report_path = Pathname.new(filename).parent.to_s
    if(not(@vortex.exists?(report_path)))
      @vortex.create_path(report_path)
    end
    @vortex.put_string(filename, data.to_json)
    @vortex.proppatch(filename,'<v:publish-date xmlns:v="vrtx">' + Time.now.httpdate.to_s + '</v:publish-date>')

  end

  # Parse published files log:
  def parse_logfile(logfile)
    uploaded_files = { }
    uploaded_files_log = open(logfile).read
    uploaded_files_log.split(/\s/).each do |line|
      type,local_filename, server_filename = line.split(':')
      uploaded_files[local_filename] = [type, server_filename.sub(@vortex_path,'')]
    end
    return uploaded_files
  end

  def generate_file_count_size_html(filelist)
    html = "  <table>\n"
    total_extension_type_count = 0
    total_file_size = 0
    filelist.keys.each do |extension|
      extension_type_count = filelist[extension][0].to_i
      total_extension_type_count = total_extension_type_count + extension_type_count
      file_size = filelist[extension][1]
      total_file_size = total_file_size + file_size
      file_size = readable_file_size(file_size, 2)

      extension_name = extension
      if(extension_name.size > 6)
        string_start = extension.size-4
        start_end = extension.size
        extension_name = "..." + extension[string_start..start_end]
      end
      html = html + "    <tr>\n"
      html = html + "      <td>" + extension_name+"</td><td align=\"right\">"+
        extension_type_count.to_s+"</td><td align=\"right\">"+file_size.to_s + "</td>\n"
      html = html + "    </tr>\n"
    end
    total_file_size = readable_file_size(total_file_size, 2)
    html = html + "    <tr >\n"
    html = html + "      <td><b>Total</b></td><td><b>" +  total_extension_type_count.to_s + "</b></td>" +
      "<td align=\"right\"><b>" + total_file_size.to_s + "</b></td>\n"
    html = html + "    </tr>\n"
    html = html + "  </table>\n"
    return html
  end

  def print_file_count_size(filelist)
    total_extension_type_count = 0
    total_file_size = 0
    filelist.keys.each do |extension|
      extension_type_count = filelist[extension][0]
      total_extension_type_count = total_extension_type_count + extension_type_count
      file_size = filelist[extension][1]
      total_file_size = total_file_size + file_size
      file_size = readable_file_size(file_size, 2)

      extension_name = extension
      if(extension_name.size > 6)
        string_start = extension.size-4
        start_end = extension.size
        extension_name = "..." + extension[string_start..start_end]
      end

      puts "  " + extension_name.ljust(20) + " :" + extension_type_count.to_s.rjust(6) + file_size.to_s.rjust(12)
    end
    puts "  " + ("-" * 40)
    total_file_size = readable_file_size(total_file_size, 2)
    puts "  " + "Totalt".ljust(20) + " :" + total_extension_type_count.to_s.rjust(6) + total_file_size.to_s.rjust(12)

  end

  # Collects report data from logfile and local filesystem:
  def collect_report_data
    report_data = { }

    # Read log file
    uploaded_files = parse_logfile(@logfile)
    report_data['uploaded_files'] = uploaded_files

    # Find local files
    local_files = []
    Find.find(@html_dir) do |path|
      if FileTest.directory?(path)
        if File.basename(path)[0] == ?.
          Find.prune
        end
      else
        local_files << path.sub(@html_path,'')
      end
    end
    report_data['local_files'] = local_files


    # Count vortex document types
    file_type_counts = { }
    uploaded_files.each do |key, val|
      type, server_path = uploaded_files[key]
      file_type_counts[type] = file_type_counts[type].to_i + 1
    end
    report_data['file_type_counts'] = file_type_counts


    # Count file extensions and calculate filesize
    extensions = { }
    uploaded_files.each do |filename, info|

      # TODO Remove temporarliy hack for PGP:
      if(filename == "http")
        next
      end
      filename = filename.gsub("http://varme.uio.no/pgp/","")

      extension = filename[/([^\.]*)$/].downcase
      extensions[extension] = [] if(not(extensions[extension]))
      count = extensions[extension][0].to_i
      filesize = extensions[extension][1].to_i
      extensions[extension][0] = count + 1
      if(not(File.exists?(@html_path + filename)))
        throw "Unknown file : '" + @html_path + filename + "' =>" + info.to_s
      end
      extensions[extension][1] = filesize + File.size(@html_path + filename)
    end
    report_data['extensions'] = extensions


    # Count file extensions and calculate filesize for unpublished files
    unpublished_files = []
    unpublished_files_extensions = { }
    local_files.each do |local_filename|
      if(not(uploaded_files[local_filename]))then
        unpublished_files << local_filename
        extension = local_filename[/([^\.]*)$/]
        unpublished_files_extensions[extension] = [] if(not(unpublished_files_extensions[extension]))
        count = unpublished_files_extensions[extension][0].to_i
        filesize = unpublished_files_extensions[extension][1].to_i
        unpublished_files_extensions[extension][0] = count + 1
        unpublished_files_extensions[extension][1] = filesize + File.size(@html_path + local_filename)
      end
    end
    report_data['unpublished_files'] = unpublished_files
    report_data['unpublished_files_extensions'] = unpublished_files_extensions

    return report_data
  end


  GIGA_SIZE = 1073741824.0
  MEGA_SIZE = 1048576.0
  KILO_SIZE = 1024.0

  # Return the file size with a readable style.
  def readable_file_size(size, precision)
    case
      when size == 1 : "1 Byte"
      when size < KILO_SIZE : "%d B " % size
      when size < MEGA_SIZE : "%.#{precision}f KB" % (size / KILO_SIZE)
      when size < GIGA_SIZE : "%.#{precision}f MB" % (size / MEGA_SIZE)
      else "%.#{precision}f GB" % (size / GIGA_SIZE)
    end
  end

end


# For testing
if $0 == __FILE__
  migration = SummerSchoolMigration.new('../site/www.summerschool.uio.no/', 'https://www-dav.vortex-demo.uio.no/konv/iss/')
  migration.logfile = 'summerschool_migration_log.txt'
  migration.debug = true
  # migration.collect_report_data

  migration.generate_report
end

