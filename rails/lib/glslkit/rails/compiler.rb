# frozen_string_literal: true

require "set"
require "propshaft/compiler"

module Glslkit
  module Rails
    # x-shader/x-vertex, x-shader/x-fragment, text/plain (§4.1) の3つに
    # 登録される。前者2つは我々専用だが、text/plainはPropshaftが配信しうる
    # 他のあらゆるプレーンテキストアセットと共有される — Propshaftはcompiler
    # の登録をcontent_typeで紐付ける(拡張子ではない)ため、これが無いと
    # このcompilerが無関係なtext/plainアセットにまで作用してしまう。
    # 以下の拡張子ガードがそれを防いでいる。
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
