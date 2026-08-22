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
      attr_reader :diagnostics

      def initialize(app)
        @app = app
        @diagnostics = []
      end

      # Validatorは常に実行し、@diagnosticsに集める(config.glslkit.validateの
      # 値によらない)。`config.glslkit.validate`は「診断を集めるかどうか」
      # ではなく「その診断を理由にビルド/リクエストを失敗させるかどうか」を
      # 制御する。呼び出し側(Glslkit::Rails.manifest / rake glslkit:reflect /
      # rake glslkit:check)がそれぞれの文脈でdiagnostics/failing?を見て
      # 反応を決める(SPEC.md §8.6)。
      def build
        @diagnostics = []
        manifest = Glslkit::Manifest.new(generated_at: Time.now.utc.iso8601)
        programs.each do |name, stages|
          vertex_source = preprocessor.process(stages.fetch(:vertex))
          fragment_source = preprocessor.process(stages.fetch(:fragment))
          validate(name, vertex_source, fragment_source)

          manifest.add_program(
            name,
            vertex: {path: stages.fetch(:vertex), source: vertex_source, url: asset_url(stages.fetch(:vertex))},
            fragment: {path: stages.fetch(:fragment), source: fragment_source, url: asset_url(stages.fetch(:fragment))}
          )
        end
        manifest.to_h
      end

      # エラーが1件でもあれば真。`fail_on_warning`が有効なら警告のみでも真。
      # config.glslkit.validateがfalseなら常に偽(検証結果があっても
      # ビルド/リクエストを失敗させない)。
      def failing?
        return false unless glslkit_config.validate

        return true if @diagnostics.any?(&:error?)

        glslkit_config.fail_on_warning && @diagnostics.any?(&:warning?)
      end

      private

      # Validator#validate は必ず Manifest.build(ここでは manifest.add_program)
      # より前に呼ぶこと(SPEC.md §8.4/§8.6)。同一ステージ内の重複などは
      # マージ後には検出できないため。
      def validate(name, vertex_source, fragment_source)
        program = Glslkit::Program.new(name: name, sources: {vertex: vertex_source, fragment: fragment_source})
        result = Glslkit::Validator.new(disabled: glslkit_config.disabled_checks).validate(program)
        @diagnostics.concat(result.diagnostics)
      end

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
