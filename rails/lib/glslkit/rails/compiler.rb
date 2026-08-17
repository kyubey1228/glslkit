# frozen_string_literal: true

require "set"
require "propshaft/compiler"

module Glslkit
  module Rails
    # Registered against x-shader/x-vertex, x-shader/x-fragment, and
    # text/plain (§4.1). The first two are exclusive to us, but text/plain is
    # shared with every other plain-text asset Propshaft might serve — since
    # Propshaft keys compiler registration by content_type, not extension,
    # this compiler would otherwise run on unrelated text/plain assets too.
    # The extension guard below is what keeps that safe.
    class Compiler < ::Propshaft::Compiler
      RELEVANT_EXTENSIONS = %w[.glsl .vert .frag].freeze

      def compile(asset, input)
        return input unless relevant?(asset)

        source = preprocess(asset)
        minify? ? Glslkit::Minifier.minify(source.code) : source.code
      end

      def referenced_by(asset)
        return Set.new unless relevant?(asset)

        source = preprocess(asset)
        source.source_map.files.drop(1).filter_map { |path| load_path.find(path) }.to_set
      end

      private

      def relevant?(asset)
        RELEVANT_EXTENSIONS.include?(asset.logical_path.extname)
      end

      def preprocess(asset)
        resolver = Glslkit::Resolvers::FileSystem.new(load_paths: load_path.paths.map(&:to_s))
        Glslkit::Preprocessor.new(resolver: resolver, line_directives: line_directives?).process(asset.logical_path.to_s)
      end

      def glslkit_config
        ::Rails.application.config.glslkit
      end

      def minify?
        glslkit_config.minify
      end

      def line_directives?
        glslkit_config.line_directives
      end
    end
  end
end
