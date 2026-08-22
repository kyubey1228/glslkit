# frozen_string_literal: true

require "json"

module Glslkit
  module Rails
    class << self
      # productionでは `rake assets:precompile` が書き出したマニフェストを
      # 読むだけ(メモ化する: プロセスが生きている間、ファイルは変化しない
      # ため)。development/testでは呼び出すたびに現在のシェーダソースから
      # 再構築する。これは config.glslkit.line_directives/minify の
      # dev-vs-production の使い分け方針(SPEC.md §4.1, §4.4)と同じ考え方。
      def manifest
        if ::Rails.env.production?
          @manifest ||= read_precompiled_manifest
        else
          build_and_log_diagnostics
        end
      end

      private

      # developmentでは検証結果をログに出すが、決して例外を投げない
      # (SPEC.md §8.6: 「development では検証するが失敗させない」)。
      # 失敗させるのは `assets:precompile` フック(rails/lib/tasks/glslkit.rake)
      # と `rake glslkit:check` の役目。
      def build_and_log_diagnostics
        builder = ManifestBuilder.new(::Rails.application)
        result = builder.build
        if ::Rails.application.config.glslkit.validate
          builder.diagnostics.each { |diagnostic| ::Rails.logger.warn("[glslkit] #{diagnostic}") }
        end
        result
      end

      def read_precompiled_manifest
        JSON.parse(File.read(manifest_path))
      end

      def manifest_path
        config = ::Rails.application.config
        config.assets.output_path.join(config.glslkit.manifest_path)
      end
    end
  end
end
