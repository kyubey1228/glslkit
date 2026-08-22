# frozen_string_literal: true

# Glslkit::Rails::LiveReload::Engine 自身のルート(M11c、SPEC-livereload.md §3.3)。
# このファイルは `Rails::Engine.root` が glslkit-rails 自体になるため、
# ホストアプリの config/routes.rb とは無関係。ホストアプリへの接続は
# glslkit-rails/lib/glslkit/rails/live_reload/mount.rb がミドルウェアとして
# 行う(理由はそちらのコメントを参照)。
Glslkit::Rails::LiveReload::Engine.routes.draw do
  get "digests.json", to: "programs#digests"
  get "programs/:name", to: "programs#show"
end
