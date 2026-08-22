# frozen_string_literal: true

module Glslkit
  module Rails
    module LiveReload
      # `/glslkit/*` へのリクエストをEngineへ振り分ける薄いミドルウェア。
      #
      # 当初は `app.routes.append { mount Engine => "/glslkit" }` を
      # Railtieのinitializerから呼ぶ形にしていたが、これは
      # `ActionDispatch::Routing::RouteSet#finalize!`(`@append`ブロックの
      # 反映はここでしか起きない)が、そのinitializerより先に一度でも
      # 走っているかどうかに依存してしまい、Railtie初期化順序次第で
      # 再現性なく404になることが実機検証で判明した(finalize!後に
      # appendしても再finalizeされない)。
      #
      # ミドルウェアスタックは全initializerが完了した後に一度だけ構築される
      # ため、`config.middleware.use`によるこの登録はタイミング非依存で
      # 安定して動く。Engine自体は本物のRails::Engineであり、内部の
      # ルーティング(digests.json / programs/:name)は変更していない。
      class Mount
        PREFIX = "/glslkit"

        def initialize(app, engine)
          @app = app
          @engine = engine
        end

        def call(env)
          path = env["PATH_INFO"]
          return @app.call(env) unless path == PREFIX || path.start_with?("#{PREFIX}/")

          # 通常の `mount` がやるのと同じ書き換え(SCRIPT_NAME/PATH_INFOの
          # 付け替え)を自分で行う。Engine自身のルート(`digests.json` /
          # `programs/:name`)はプレフィックス無しのパスとして定義している
          # ため、これをしないとEngine内のルーティングが一致しない。
          rest = path.delete_prefix(PREFIX)
          rest = "/#{rest}".squeeze("/")

          env = env.merge(
            "SCRIPT_NAME" => "#{env["SCRIPT_NAME"]}#{PREFIX}",
            "PATH_INFO" => rest
          )
          @engine.call(env)
        end
      end
    end
  end
end
