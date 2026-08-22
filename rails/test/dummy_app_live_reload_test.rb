# frozen_string_literal: true

require "test_helper"
require_relative "dummy_app_test_helper"
require "json"
require "tmpdir"

# M11c: ライブリロードの2エンドポイント(SPEC-livereload.md §3.3)。
# サブプロセスの `bin/rails runner` に、そのプロセス内でHTTPリクエストを
# 組み立てて実行するスクリプトを渡す方式で検証する(実TCPサーバを
# 起動する必要がなく、既存のサブプロセステスト規約とも一貫する)。
class DummyAppLiveReloadTest < Minitest::Test
  include DummyAppTestHelper

  def test_digests_json_returns_source_digests_for_every_program
    result = request_json("/glslkit/digests.json")

    assert_equal 200, result["status"]
    assert_equal %w[material pbr], result["body"].keys.sort
    assert_match(/\A[0-9a-f]+\z/, result["body"]["pbr"])
  end

  def test_programs_show_returns_the_full_payload_for_a_known_program
    result = request_json("/glslkit/programs/pbr.json")

    assert_equal 200, result["status"]
    body = result["body"]
    assert_equal "pbr", body["name"]
    refute_nil body["source_digest"]
    assert_includes body["vertex"], "gl_Position"
    assert_equal %w[fragment vertex], body["source_maps"].keys.sort
    assert_equal "pbr", body.dig("manifest", "programs").keys.first
  end

  def test_programs_show_returns_404_for_an_unknown_name
    result = request_json("/glslkit/programs/does-not-exist.json")

    assert_equal 404, result["status"]
  end

  # :name はDiscoverされたプログラム名とのHash lookupにしか使わないため、
  # パストラバーサルを試みても実在しない名前として404になるだけで、
  # ファイルパスの組み立てには一切使われない。
  def test_programs_show_rejects_a_path_traversal_attempt_in_name
    result = request_json("/glslkit/programs/..%2F..%2F..%2Fetc%2Fpasswd.json")

    assert_equal 404, result["status"]
  end

  def test_route_is_not_mounted_in_production
    Dir.mktmpdir do |dir|
      script_path = File.join(dir, "script.rb")
      File.write(script_path, request_script("/glslkit/digests.json"))

      env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE" => "x" * 64, "GLSLKIT_TEST_PUBLIC_ROOT" => dir}
      stdout, stderr, status = run_in_dummy_app("bin/rails", "runner", script_path, env: env)
      assert status.success?, "#{stdout}\n#{stderr}"

      result = JSON.parse(stdout.lines.last)
      assert_equal 404, result["status"]
    end
  end

  def test_validation_failure_returns_200_with_diagnostics_and_a_source_digest
    with_shader_pair("broken", vertex: VALID_VERTEX, fragment: DUPLICATE_UNIFORM_FRAGMENT) do
      result = request_json("/glslkit/programs/broken.json")

      assert_equal 200, result["status"]
      body = result["body"]
      refute_nil body["source_digest"]
      assert_equal "validation", body.dig("error", "kind")
      assert(body.dig("error", "diagnostics").any? { |d| d["code"] == "E006" })
    end
  end

  def test_preprocess_failure_returns_200_with_error_info_and_a_source_digest
    with_shader_pair("broken", vertex: VALID_VERTEX, fragment: MISSING_INCLUDE_FRAGMENT) do
      result = request_json("/glslkit/programs/broken.json")

      assert_equal 200, result["status"]
      body = result["body"]
      refute_nil body["source_digest"]
      assert_equal "preprocess", body.dig("error", "kind")
      assert_equal "Glslkit::IncludeNotFound", body.dig("error", "class")
    end
  end

  def test_source_digest_changes_when_a_broken_shader_is_re_saved
    with_shader_pair("broken", vertex: VALID_VERTEX, fragment: MISSING_INCLUDE_FRAGMENT) do |frag_path|
      first = request_json("/glslkit/programs/broken.json")

      File.write(frag_path, "#include \"still-missing.glsl\"\nout vec4 fragColor;\nvoid main() {}\n")
      second = request_json("/glslkit/programs/broken.json")

      refute_equal first["body"]["source_digest"], second["body"]["source_digest"]
    end
  end

  private

  VALID_VERTEX = "in vec3 a_position;\nvoid main() { gl_Position = vec4(a_position, 1.0); }\n"
  DUPLICATE_UNIFORM_FRAGMENT = "uniform float u_x;\nuniform vec3 u_x;\nout vec4 fragColor;\nvoid main() { fragColor = vec4(1.0); }\n"
  MISSING_INCLUDE_FRAGMENT = "#include \"does-not-exist.glsl\"\nout vec4 fragColor;\nvoid main() {}\n"

  def shaders_dir
    File.expand_path("dummy/app/shaders", __dir__)
  end

  def with_shader_pair(name, vertex:, fragment:)
    vert_path = File.join(shaders_dir, "#{name}.vert")
    frag_path = File.join(shaders_dir, "#{name}.frag")
    File.write(vert_path, vertex)
    File.write(frag_path, fragment)
    yield frag_path
  ensure
    File.delete(vert_path) if vert_path && File.exist?(vert_path)
    File.delete(frag_path) if frag_path && File.exist?(frag_path)
  end

  def request_json(path)
    Dir.mktmpdir do |dir|
      script_path = File.join(dir, "script.rb")
      File.write(script_path, request_script(path))

      stdout, stderr, status = run_in_dummy_app("bin/rails", "runner", script_path, env: {"RAILS_ENV" => "test"})
      assert status.success?, "#{stdout}\n#{stderr}"
      JSON.parse(stdout.lines.last)
    end
  end

  def request_script(path)
    <<~RUBY
      require "json"
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.get(#{path.inspect})
      body = session.response.body.empty? ? nil : JSON.parse(session.response.body)
      puts({status: session.response.status, body: body}.to_json)
    RUBY
  end
end
