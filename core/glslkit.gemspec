# frozen_string_literal: true

require_relative "lib/glslkit/version"

Gem::Specification.new do |spec|
  spec.name = "glslkit"
  spec.version = Glslkit::VERSION
  spec.authors = ["kyubey1228"]
  spec.email = ["kyuuka1228@gmail.com"]

  spec.summary = "GLSL preprocessing and reflection toolkit"
  spec.description = "Flattens #include directives in GLSL shaders and extracts " \
    "uniform/attribute/output reflection data as JSON, with zero runtime " \
    "dependencies so it can run under ruby.wasm."
  spec.homepage = "https://github.com/kyubey1228/glslkit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main/core"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/core/CHANGELOG.md"

  spec.files = Dir.glob("lib/**/*.rb") + ["glslkit.gemspec"]
  spec.require_paths = ["lib"]
end
