# frozen_string_literal: true

require_relative "boot"

require "rails" # the "railties" gem's entry point; loads Rails::Application + ActionDispatch, nothing more (not rails/all)
# Needed so ActionDispatch::Static (which Propshaft's dev-mode Server middleware
# sits behind) can resolve ActionController::Base. Deliberately not requiring
# active_record/railtie — no DB config needed for anything glslkit-rails does.
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
