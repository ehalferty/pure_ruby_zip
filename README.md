# PureRubyZip

A pure-Ruby ZIP file decompressor/compressor.
VERY inefficient, possibly buggy.
Mostly for entertainment value.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pure_ruby_zip'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pure_ruby_zip

## Usage

This comes with a command-line script. Run it like so:

```bash
pure-ruby-zip test123.zip
```

You can also include this in your own program.

```ruby
require "pure_ruby_zip"
```

To pre-process a ZIP file (cache the filenames and offsets):
```ruby
z = ZipFile.new "test12.zip"
```

To get a list of extractable files:
```ruby
z.items
```

To extract a file by name:
```ruby
file_data = z.decompress_file "test1.txt"
```

To extract all files:
```ruby
file_names_and_data = z.decompress_all_files "test12.zip"
```

To extract all files, and _save them to disk_:
```ruby
z.decompress_all_files_to_disk "test12.zip"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ehalferty/pure_ruby_zip.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
