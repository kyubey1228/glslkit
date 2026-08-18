# frozen_string_literal: true

require "digest"

module Glslkit
  # stdlibの `digest` を要求するのはこのファイルだけにする(M8g)。
  # `glslkit/runtime`(wasm向けの狭い入口)はこのファイルをrequireしないため、
  # マニフェストの読み込み・SourceMapの復元だけならdigestはロードされない。
  module Digest
    module_function

    # 定数探索はこのモジュール自身より先にこのレキシカルスコープを見るため、
    # 曖昧さを避けて常にトップレベルの `::Digest` を明示する。
    def hexdigest(string)
      ::Digest::SHA256.hexdigest(string)
    end
  end
end
