# frozen_string_literal: true

require_relative "lib/glslkit/webgl/version"

Gem::Specification.new do |spec|
  spec.name = "glslkit-webgl"
  spec.version = Glslkit::WebGL::VERSION
  spec.authors = ["kyubey1228"]
  spec.email = ["kyuuka1228@gmail.com"]

  spec.summary = "ruby.wasm WebGL2 binding that consumes glslkit reflection manifests"
  spec.description = "Lets you write WebGL2 rendering code entirely in Ruby, running under " \
    "ruby.wasm in the browser. Resolves uniform/attribute locations from a glslkit " \
    "reflection manifest instead of calling getActiveUniform, and surfaces shader " \
    "compile errors as Ruby exceptions pointing at the original file and line."
  spec.homepage = "https://github.com/kyubey1228/glslkit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main/webgl"

  spec.files = Dir.glob("lib/**/*.rb") + Dir.glob("shim/**/*.js") + Dir.glob("sample/**/*") +
    ["glslkit-webgl.gemspec", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "glslkit", "~> 0.1"
end
