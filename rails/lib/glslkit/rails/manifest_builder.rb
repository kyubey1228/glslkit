# frozen_string_literal: true

require "time"

module Glslkit
  module Rails
    # config.glslkit.paths 配下からvertex/fragmentのペアを検出し、その
    # すべてについて reflection-v1.json のマニフェスト(Glslkit::Manifest, M4)
    # を組み立てる。stage.urlは Rails.application.assets.resolver 経由で
    # 解決する。これはasset_path/asset_urlが内部で使っているのとまさに同じ
    # 経路であり、developmentではDynamic、assets:precompile実行後はStatic
    # (Propshaftが直前に書いた.manifest.jsonを読む)になる。
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

      # {"pbr" => {vertex: "pbr.vert", fragment: "pbr.frag"}, ...} を返す。
      # 同名の相方が無い.vert/.fragはスキップする(SPEC.md §2.4/§3: プログラム
      # は両ステージが必須だが、app/shaders配下の.vert/.frag全てがプログラム
      # になることを意図しているわけではない。例えば共有partialの場合)。
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
