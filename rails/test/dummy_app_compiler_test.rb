# frozen_string_literal: true

require "test_helper"
require_relative "dummy_app_test_helper"

class DummyAppCompilerTest < Minitest::Test
  include DummyAppTestHelper

  def test_content_types_are_registered_without_clobbering_text_plain
    script = <<~RUBY
      require "json"
      vert = Rails.application.assets.load_path.find("pbr.vert").content_type.to_s
      frag = Rails.application.assets.load_path.find("pbr.frag").content_type.to_s
      glsl = Rails.application.assets.load_path.find("common/math.glsl").content_type.to_s
      text_plain = Mime::Type.lookup("text/plain")
      puts({
        vert: vert, frag: frag, glsl: glsl,
        text_plain_symbol: text_plain.symbol, text_plain_string: text_plain.to_s
      }.to_json)
    RUBY
    stdout, stderr, status = run_in_dummy_app("bin/rails", "runner", script, env: {"RAILS_ENV" => "test"})
    assert status.success?, stderr

    result = JSON.parse(stdout.lines.last)
    assert_equal "x-shader/x-vertex", result["vert"]
    assert_equal "x-shader/x-fragment", result["frag"]
    assert_equal "text/plain", result["glsl"]
    # register_aliasが既存の text/plain => :text という登録を上書きしていないこと
    assert_equal "text", result["text_plain_symbol"]
    assert_equal "text/plain", result["text_plain_string"]
  end

  def test_include_is_flattened_with_line_directives
    script = <<~RUBY
      content = Rails.application.assets.load_path.find("pbr.frag").compiled_content
      puts content
    RUBY
    stdout, stderr, status = run_in_dummy_app("bin/rails", "runner", script, env: {"RAILS_ENV" => "test"})
    assert status.success?, stderr

    refute_includes stdout, "#include"
    assert_includes stdout, "#line"
    assert_includes stdout, "float pi() { return 3.14159265; }"
  end

  def test_included_files_are_tracked_as_references_for_cache_busting
    script = <<~RUBY
      asset = Rails.application.assets.load_path.find("pbr.frag")
      referenced = Rails.application.assets.load_path.find_referenced_by(asset)
      puts referenced.map(&:logical_path).map(&:to_s).sort.inspect
    RUBY
    stdout, stderr, status = run_in_dummy_app("bin/rails", "runner", script, env: {"RAILS_ENV" => "test"})
    assert status.success?, stderr

    assert_equal '["common/math.glsl"]', stdout.strip
  end

  def test_asset_is_served_through_the_middleware_stack_at_its_digested_url
    script = <<~'RUBY'
      require "json"
      require "rack/test"
      asset = Rails.application.assets.load_path.find("pbr.frag")
      response = Rack::MockRequest.new(Rails.application).get("/assets/#{asset.digested_path}")
      puts({status: response.status, content_type: response.headers["Content-Type"], body: response.body}.to_json)
    RUBY
    stdout, stderr, status = run_in_dummy_app("bin/rails", "runner", script, env: {"RAILS_ENV" => "test"})
    assert status.success?, stderr

    result = JSON.parse(stdout.lines.last)
    assert_equal 200, result["status"]
    assert_equal "x-shader/x-fragment", result["content_type"]
    assert_includes result["body"], "#line"
    refute_includes result["body"], "#include"
  end
end
