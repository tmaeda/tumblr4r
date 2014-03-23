# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tumblr4r/version'

Gem::Specification.new do |spec|
  spec.name          = "tumblr4r"
  spec.version       = Tumblr4r::VERSION
  spec.authors       = ["Tomoki MAEDA"]
  spec.email         = ["tmaeda@ruby-sapporo.org"]
  spec.summary       = "Tumblr API Wrapper for Ruby"
  spec.homepage      = "https://github.com/tmaeda/tumblr4r"
  spec.license       = "Ruby's license"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency 'pit', '>= 0.0.6'
end
