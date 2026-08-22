# frozen_string_literal: true

require "rails/engine"

module Glslkit
  module Rails
    module LiveReload
      # ライブリロード用の2エンドポイント(§3.3)を提供するEngine。
      # `isolate_namespace` によりホストアプリの `ProgramsController` 等と
      # 衝突しない。マウントは `Railtie` が `config.glslkit.live_reload` を
      # 見て判断する — このEngineが定義されていること自体は production でも
      # 構わない(未マウントならルートは一切生成されない)。
      class Engine < ::Rails::Engine
        isolate_namespace Glslkit::Rails::LiveReload

        routes.draw do
          get "digests.json", to: "programs#digests"
          get "programs/:name", to: "programs#show"
        end
      end
    end
  end
end
