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
  end
end
