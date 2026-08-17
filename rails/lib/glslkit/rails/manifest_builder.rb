# frozen_string_literal: true

require "time"

module Glslkit
  module Rails
    # Discovers vertex/fragment pairs under config.glslkit.paths and builds
    # the reflection-v1.json manifest (Glslkit::Manifest, M4) for all of them.
    # stage.url is resolved through Rails.application.assets.resolver, which
    # is exactly what asset_path/asset_url use internally — Dynamic in
    # development, or Static (reading Propshaft's own just-written
    # .manifest.json) once assets:precompile has run.
    class ManifestBuilder
      def initialize(app)
        @app = app
      end

      def build
        manifest = Glslkit::Manifest.new(generated_at: Time.now.utc.iso8601)
        programs.each do |name, stages|
          manifest.add_program(name, vertex: stage_input(stages.fetch(:vertex)), fragment: stage_input(stages.fetch(:fragment)))
        end
        manifest.to_h
      end

      private

      def glslkit_config
        @app.config.glslkit
      end

      def shader_roots
        glslkit_config.paths.map { |path| @app.root.join(path).to_s }
      end

      # {"pbr" => {vertex: "pbr.vert", fragment: "pbr.frag"}, ...}, skipping
      # any .vert/.frag left without a same-named partner (SPEC.md §2.4/§3:
      # a program requires both stages, but not every .vert/.frag file under
      # app/shaders is necessarily meant to be one, e.g. a shared partial).
      def programs
        by_name = Hash.new { |h, k| h[k] = {} }

        shader_roots.each do |root|
          Dir.glob("**/*.{vert,frag}", base: root).each do |relative|
            ext = File.extname(relative)
            stage = (ext == ".vert") ? :vertex : :fragment
            by_name[relative.delete_suffix(ext)][stage] = relative
          end
        end

        by_name.select { |_, stages| stages.key?(:vertex) && stages.key?(:fragment) }
      end

      def stage_input(relative_path)
        {path: relative_path, source: preprocessor.process(relative_path), url: asset_url(relative_path)}
      end

      def preprocessor
        @preprocessor ||= Glslkit::Preprocessor.new(
          resolver: Glslkit::Resolvers::FileSystem.new(load_paths: shader_roots),
          line_directives: glslkit_config.line_directives
        )
      end

      def asset_url(relative_path)
        @app.assets.resolver.resolve(relative_path)
      end
    end
  end
end
