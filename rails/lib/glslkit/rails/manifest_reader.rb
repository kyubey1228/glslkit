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
          ManifestBuilder.new(::Rails.application).build
        end
      end

      private

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
