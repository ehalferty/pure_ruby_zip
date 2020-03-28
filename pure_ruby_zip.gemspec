
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "pure_ruby_zip/version"

Gem::Specification.new do |spec|
  spec.name          = "pure_ruby_zip"
  spec.version       = PureRubyZip::VERSION
  spec.authors       = ["Edward Halferty"]
  spec.email         = ["me@edwardhalferty.com"]

  spec.summary       = "A pure-Ruby ZIP file decompressor/compressor"
  spec.description   = %q(
    A pure-Ruby ZIP file decompressor/compressor.
    VERY inefficient, possibly buggy.
    Mostly for entertainment value.
  ).strip
  spec.homepage      = "https://github.com/ehalferty/pure_ruby_zip"
  spec.license       = "MIT"

  spec.bindir        = "bin"
  spec.executables   = ["pure-ruby-zip"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
end
