require "./lib/pure_ruby_zip"

PureRubyZip::ZipFile.new("test12.zip").decompress_all_files_to_disk
