# frozen_string_literal: true

# M11e: development専用のライブリロード監視ループ(SPEC-livereload.md §4.4)。
# `glslkit/webgl` からは自動でrequireされない — 使う側が明示的に
# `require "glslkit/webgl/live_reload"` すること(決定3)。production相当の
# 環境ではこのファイル自体をrequireしないことで対処する。エンドポイントが
# 存在しない場合の404ハンドリングは不要(そもそも呼ばれない)。
#
# spike/09-fetch.htmlの実機確認(SPEC-livereload.md §4.4)により、
# `JS::Object#await` はここでは使えないことが分かっている。`.then` + Proc
# だけで組む。
require "json"

module Glslkit
  module WebGL
    class Context
      LIVE_RELOAD_POLL_INTERVAL_MS = 500
      LIVE_RELOAD_DIGESTS_PATH = "/glslkit/digests.json"

      # ctx.live_reload("neon", on_error: ->(e) { ... }, on_reload: -> { ... })
      #
      # 決定4: 1ページにつきsetIntervalは1本。2回目以降の呼び出しは監視対象の
      # リストに追加するだけで、既存のポーリングに乗せる。
      def live_reload(name, on_error: nil, on_reload: nil)
        @live_reload_watches ||= {}
        @live_reload_watches[name.to_s] = {digest: nil, on_error: on_error, on_reload: on_reload}
        start_live_reload_polling unless @live_reload_interval_id
        self
      end

      private

      def start_live_reload_polling
        tick = proc { poll_live_reload_digests }
        @live_reload_interval_id = JS.global.call(:setInterval, tick, LIVE_RELOAD_POLL_INTERVAL_MS)
      end

      def poll_live_reload_digests
        fetch_json(LIVE_RELOAD_DIGESTS_PATH,
          on_success: ->(digests) { apply_live_reload_digests(digests) },
          on_error: ->(error) { @live_reload_watches.each_value { |watch| watch[:on_error]&.call(error) } })
      end

      # digestが変わっていないプログラムは本体を取得しない。
      def apply_live_reload_digests(digests)
        @live_reload_watches.each do |name, watch|
          new_digest = digests[name]
          next if new_digest.nil? || new_digest == watch[:digest]

          fetch_and_reload_program(name, watch)
        end
      end

      def fetch_and_reload_program(name, watch)
        fetch_json("/glslkit/programs/#{name}.json",
          on_success: ->(payload) { apply_live_reload_payload(name, watch, payload) },
          on_error: ->(error) { watch[:on_error]&.call(error) })
      end

      # 失敗時に既存の状態を壊さないこと(§4.1)。reload_programが
      # CompileError/LinkError/ReloadIncompatibleErrorを投げても、ここで
      # 捕まえてon_errorへ回すだけで、監視ループ自体は止めない。
      def apply_live_reload_payload(name, watch, payload)
        watch[:digest] = payload["source_digest"]

        if payload.key?("error")
          watch[:on_error]&.call(payload.fetch("error"))
          return
        end

        source_maps = payload.fetch("source_maps")
        result = reload_program(name,
          vertex: payload.fetch("vertex"), fragment: payload.fetch("fragment"),
          manifest: payload.fetch("manifest"),
          source_maps: {vertex: source_maps.fetch("vertex"), fragment: source_maps.fetch("fragment")})
        watch[:on_reload]&.call(result)
      rescue => e
        watch[:on_error]&.call(e)
      end

      # fetch → .then(response) → text() → .then(text) → JSON.parse という
      # 定型処理をまとめる。ok?がfalseの応答も、rejectされたPromiseと同様に
      # on_errorへ回す。
      def fetch_json(path, on_success:, on_error:)
        on_response = proc do |response|
          if response[:ok] == JS::True
            response.call(:text)
          else
            on_error.call("fetch #{path} failed: status=#{response[:status]}")
            nil
          end
        end
        on_text = proc do |text|
          next if text.nil?

          begin
            on_success.call(JSON.parse(text.to_s))
          rescue => e
            on_error.call(e)
          end
        end
        on_rejected = proc { |error| on_error.call(error) }
        JS.global.fetch(path).call(:then, on_response).call(:then, on_text).call(:catch, on_rejected)
      end
    end
  end
end
