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
      #
      # ルートは `rails/config/routes.rb`(このEngineの root 直下)に書いて
      # いる。クラス本体で直接 `routes.draw do ... end` する形も動くが、
      # それは一度きりの実行にしかならない。Rails::Engineは自身のroute_setを
      # `app.routes_reloader.route_sets` に登録し、アプリのルートリロード
      # サイクルで一緒に clear!/reload される — Rails 7.2ではこの
      # サイクルで実際に一度 clear! されるため、クラス本体に書いた内容は
      # 再度描画されず空になって消える(Rails 8.1では起きなかったため
      # 実機検証で気づくまで見逃していた)。`config/routes.rb` ファイルに
      # すればreload時に毎回 `load` され直すため、バージョンに関わらず安定する。
      class Engine < ::Rails::Engine
        isolate_namespace Glslkit::Rails::LiveReload
      end
    end
  end
end
