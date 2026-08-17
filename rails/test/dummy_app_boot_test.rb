# frozen_string_literal: true

require "test_helper"
require_relative "dummy_app_test_helper"

class DummyAppBootTest < Minitest::Test
  include DummyAppTestHelper

  def test_runner_boots_in_development
    stdout, stderr, status = run_in_dummy_app("bin/rails", "runner", "puts 1")

    assert status.success?, stderr
    assert_equal "1", stdout.strip
  end

  def test_runner_boots_in_test_env
    stdout, stderr, status = run_in_dummy_app("bin/rails", "runner", "puts Rails.env", env: {"RAILS_ENV" => "test"})

    assert status.success?, stderr
    assert_equal "test", stdout.strip
  end

  def test_glslkit_config_defaults_are_registered
    script = <<~RUBY
      c = Rails.application.config.glslkit
      puts [c.paths, c.minify, c.line_directives, c.manifest_path].inspect
    RUBY
    stdout, stderr, status = run_in_dummy_app("bin/rails", "runner", script)

    assert status.success?, stderr
    assert_equal '[["app/shaders"], false, true, "glsl-manifest.json"]', stdout.strip
  end
end
