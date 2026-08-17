# frozen_string_literal: true

require "glslkit"
require "propshaft"
require_relative "rails/version"
require_relative "rails/railtie"

module Glslkit
  module Rails
    # NOTE: inside this namespace, the bare constant `Rails` resolves to
    # `Glslkit::Rails` itself, not the top-level Rails framework. Always
    # write `::Rails` when referring to the framework (e.g. `::Rails::Engine`).
  end
end
