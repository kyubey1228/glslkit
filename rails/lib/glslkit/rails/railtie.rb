# frozen_string_literal: true

require "rails/railtie"

module Glslkit
  module Rails
    class Railtie < ::Rails::Railtie
      config.glslkit = ActiveSupport::OrderedOptions.new
      config.glslkit.paths = ["app/shaders"]
      config.glslkit.minify = ::Rails.env.production?
      config.glslkit.line_directives = !::Rails.env.production?
      config.glslkit.manifest_path = "glsl-manifest.json"

      # Uses Mime::Type.register (the path Propshaft::Asset#content_type
      # itself resolves through), not Marcel directly — Marcel is only an
      # internal, transitive detail of Propshaft, not something to couple to.
      initializer "glslkit.register_mime_types" do
        ::Mime::Type.register "x-shader/x-vertex", :vert unless ::Mime::Type.lookup_by_extension("vert")
        ::Mime::Type.register "x-shader/x-fragment", :frag unless ::Mime::Type.lookup_by_extension("frag")
        # register_alias, not register: "text/plain" is already registered under :text,
        # and re-registering the same string under :glsl would overwrite that lookup entry.
        ::Mime::Type.register_alias "text/plain", :glsl unless ::Mime::Type.lookup_by_extension("glsl")
      end

      initializer "glslkit.configure_propshaft", before: "propshaft.assets_middleware" do |app|
        app.config.glslkit.paths.each do |path|
          app.config.assets.paths << ::Rails.root.join(path).to_s
        end

        %w[x-shader/x-vertex x-shader/x-fragment text/plain].each do |mime_type|
          app.config.assets.compilers << [mime_type, Glslkit::Rails::Compiler]
        end
      end
    end
  end
end
