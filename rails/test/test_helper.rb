# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../core/lib", __dir__)
require "rails" # Glslkit::Rails::Railtieは本物のRails::Railtieなので、Rails.env等が存在している必要がある
require "glslkit/rails"

require "minitest/autorun"
