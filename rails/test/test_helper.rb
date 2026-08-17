# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../core/lib", __dir__)
require "rails" # Glslkit::Rails::Railtie is a real Rails::Railtie, so Rails.env etc. must exist
require "glslkit/rails"

require "minitest/autorun"
