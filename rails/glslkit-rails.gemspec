# frozen_string_literal: true

require_relative "lib/glslkit/rails/version"

Gem::Specification.new do |spec|
  spec.name = "glslkit-rails"
  spec.version = Glslkit::Rails::VERSION
  spec.authors = ["kyubey1228"]
  spec.email = ["kyuuka1228@gmail.com"]

  spec.summary = "Rails (Propshaft) integration for glslkit"
  spec.description = "Registers .glsl/.vert/.frag assets with Propshaft, resolves " \
    "#include directives at request/precompile time, and publishes a shader " \
    "reflection manifest for consumption by views and JS at runtime."
  spec.homepage = "https://github.com/kyubey1228/glslkit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main/rails"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/rails/CHANGELOG.md"

  spec.files = Dir.glob("lib/**/*.{rb,rake}") +
    ["glslkit-rails.gemspec", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "glslkit", "~> 0.1"
  spec.add_dependency "railties", ">= 7.1"
  # 実際にインストールされた1.3.2で確認したCompiler API
  # (Propshaft::Compiler#compile(asset, input), #referenced_by(asset),
  # Propshaft::Compilers#register(mime_type, klass)) に合わせて固定している。
  # それより古い1.x系では確認していないため、より広い範囲は主張しない。
  spec.add_dependency "propshaft", ">= 1.3.2"
end
