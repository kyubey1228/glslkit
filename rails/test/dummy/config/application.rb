# frozen_string_literal: true

require_relative "boot"

require "rails" # "railties" gemの入り口。Rails::Application + ActionDispatchのみを読み込む(rails/allではない)
# ActionDispatch::Static (Propshaftのdev-modeのServerミドルウェアはその
# 裏側に位置する) が ActionController::Base を参照するために必要。
# active_record/railtie は意図的にrequireしていない —
# glslkit-railsが行うことにDB設定は一切不要なため。
require "action_controller/railtie"
require "glslkit/rails"

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.1

    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new(IO::NULL)
    config.log_level = :fatal

    # glsl_script_tag/glsl_manifest_tagのCSP nonce対応をエンドツーエンドで
    # 検証するためのテスト用設定。実アプリで有効にする場合と同じキーを使う。
    config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.hex(16) }
    config.content_security_policy_nonce_directives = %w[script-src]
    config.content_security_policy_nonce_auto = true
  end
end
