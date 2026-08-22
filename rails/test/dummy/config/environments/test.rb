# frozen_string_literal: true

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = false
  config.public_file_server.enabled = true

  # 既定は Rails.env.development? だが、testでもライブリロード
  # エンドポイント(M11c)をテストできるようにここで有効にする。
  # productionではRails.env.development?がfalseのままなので影響しない。
  config.glslkit.live_reload = true
end
