# frozen_string_literal: true

require "test_helper"
require_relative "dummy_app_test_helper"
require "json"

class DummyAppHelperTest < Minitest::Test
  include DummyAppTestHelper

  def get(action)
    script = <<~RUBY
      require "json"
      require "rack/test"
      response = Rack::MockRequest.new(Rails.application).get("/glsl_helper_test/#{action}")
      puts({status: response.status, body: response.body}.to_json)
    RUBY
    stdout, stderr, status = run_in_dummy_app("bin/rails", "runner", script, env: {"RAILS_ENV" => "test"})
    assert status.success?, stderr
    JSON.parse(stdout.lines.last)
  end

  def test_glsl_script_tag_and_glsl_manifest_tag_render_inline
    result = get("show")
    body = result["body"]

    assert_match(/<script id="pbr-vert" type="x-shader\/x-vertex"[^>]*>/, body)
    assert_includes body, "#line"
    assert_includes body, "gl_Position"

    manifest_match = body.match(%r{<script id="glsl-manifest" type="application/json"[^>]*>(.*?)</script>}m)
    refute_nil manifest_match, "expected a glsl-manifest script tag"
    manifest = JSON.parse(manifest_match[1])
    assert_equal 1, manifest["schema_version"]
    assert_equal %w[material pbr], manifest["programs"].keys.sort
  end

  def test_nonce_is_applied_automatically_when_configured
    result = get("show")
    body = result["body"]

    nonces = body.scan(/nonce="([0-9a-f]+)"/).flatten
    assert_equal 2, nonces.size, body
    # a nonce is per-response, not per-tag: content_security_policy_nonce memoizes
    # on the request, so both glsl tags in the same response share one value
    assert_equal nonces[0], nonces[1]
  end

  def test_nonce_is_applied_even_when_the_action_has_its_own_csp_policy
    body = get("with_csp")["body"]

    assert_match(/nonce="[0-9a-f]+"/, body)
  end

  def test_nonce_false_suppresses_the_attribute
    body = get("nonce_suppressed")["body"]

    refute_includes body, "nonce="
  end

  def test_embedded_closing_script_tags_are_escaped
    body = get("escape_test")["body"]

    refute_includes body, "</script>\n// this comment"
    assert_includes body, '<\/script>'
    # exactly one real closing </script>, for the tag glsl_script_tag itself emitted
    assert_equal 1, body.scan("</script>").size
  end
end
