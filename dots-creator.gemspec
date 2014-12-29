# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dots/creator/version'

Gem::Specification.new do |spec|
  spec.name          = "dots-creator"
  spec.version       = Dots::Creator::VERSION
  spec.authors       = ["dhyan"]
  spec.email         = ["dhyanbaba@gmail.com"]
  spec.summary       = %q{Get the dots for google maps.}
  spec.description   = %q{Get dots based on population in kml files.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_dependency "rake"
  spec.add_dependency 'rubyzip'
  spec.add_dependency 'httparty'
  spec.add_dependency 'nokogiri', '~> 1.6.1'
  spec.add_dependency 'rgeo'
end
