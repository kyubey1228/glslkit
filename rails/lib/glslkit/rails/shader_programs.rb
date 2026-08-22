# frozen_string_literal: true

module Glslkit
  module Rails
    # `config.glslkit.paths` 配下の .vert/.frag ペアを名前ごとに集める。
    # `ManifestBuilder`(静的な precompile)と `LiveReload::ProgramsController`
    # (M11c、ポーリング用のエンドポイント)の両方が全く同じ発見ロジックを
    # 必要とするため、ここに1箇所へ集約する。
    module ShaderPrograms
      module_function

      def roots(app)
        app.config.glslkit.paths.map { |path| app.root.join(path).to_s }
      end

      # {"pbr" => {vertex: "pbr.vert", fragment: "pbr.frag"}, ...} を返す。
      # 同名の相方が無い .vert/.frag はスキップする(共有partialの可能性が
      # あるため。SPEC.md §2.4/§3の「プログラムは両ステージ必須」の決定)。
      def discover(app)
        by_name = Hash.new { |h, k| h[k] = {} }

        roots(app).each do |root|
          Dir.glob("**/*.{vert,frag}", base: root).each do |relative|
            ext = File.extname(relative)
            stage = (ext == ".vert") ? :vertex : :fragment
            by_name[relative.delete_suffix(ext)][stage] = relative
          end
        end

        by_name.select { |_, stages| stages.key?(:vertex) && stages.key?(:fragment) }
      end
    end
  end
end
