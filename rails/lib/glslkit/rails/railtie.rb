# frozen_string_literal: true

require "rails/railtie"

module Glslkit
  module Rails
    class Railtie < ::Rails::Railtie
      config.glslkit = ActiveSupport::OrderedOptions.new
      config.glslkit.paths = ["app/shaders"]
      config.glslkit.minify = ::Rails.env.production?
      config.glslkit.line_directives = !::Rails.env.production?
      config.glslkit.manifest_path = "glsl-manifest.json"
    end
  end
end
