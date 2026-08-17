# frozen_string_literal: true

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.public_file_server.enabled = true

  # precompileのみ: その場コンパイルへのフォールバックを無効にする。
  # これにより assets:precompile のテストが通ることが「実際にマニフェスト
  # が書き出された」ことの証明になる(ライブコンパイル経路にすり抜けられて
  # 壊れたタスクが見逃されることがない)。
  config.assets.compile = false

  # テスト実行中はprecompileの出力先をリポジトリ外に逃がす。これにより
  # テストスイートを実行しても test/dummy/public 配下に生成物がコミット
  # されてしまうことがない。
  if ENV["GLSLKIT_TEST_PUBLIC_ROOT"].present?
    config.paths["public"] = ENV["GLSLKIT_TEST_PUBLIC_ROOT"]
  end
end
