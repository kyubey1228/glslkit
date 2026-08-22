# frozen_string_literal: true

require "test_helper"
require_relative "dummy_app_test_helper"
require "json"
require "json_schemer"
require "tmpdir"

class DummyAppPrecompileTest < Minitest::Test
  include DummyAppTestHelper

  SCHEMA_PATH = File.expand_path("../../spec/schema/reflection-v1.json", __dir__)

  def test_precompile_emits_a_schema_valid_manifest
    Dir.mktmpdir do |public_root|
      stdout, stderr, status = precompile(public_root)
      assert status.success?, "#{stdout}\n#{stderr}"

      manifest = read_manifest(public_root)
      schema = JSONSchemer.schema(JSON.parse(File.read(SCHEMA_PATH)))
      assert schema.valid?(manifest), schema.validate(manifest).to_a.inspect

      program = manifest["programs"]["pbr"]
      assert_equal 1, manifest["schema_version"]
      assert_equal ["a_position"], program["attributes"].map { |a| a["name"] }
      assert_equal ["fragColor"], program["outputs"].map { |o| o["name"] }
      assert_match %r{\A/assets/pbr-[0-9a-f]+\.vert\z}, program["stages"]["vertex"]["url"]
      assert_match %r{\A/assets/pbr-[0-9a-f]+\.frag\z}, program["stages"]["fragment"]["url"]
    end
  end

  def test_material_program_reflects_uniform_arrays_and_a_shared_uniform_block
    Dir.mktmpdir do |public_root|
      stdout, stderr, status = precompile(public_root)
      assert status.success?, "#{stdout}\n#{stderr}"

      program = read_manifest(public_root)["programs"]["material"]
      uniforms_by_name = program["uniforms"].to_h { |u| [u["name"], u] }

      assert_equal %w[a_position a_normal a_uv], program["attributes"].map { |a| a["name"] }
      assert_equal [0, 1, 2], program["attributes"].map { |a| a["location"] }

      light_positions = uniforms_by_name.fetch("u_light_positions")
      assert_equal "vec3", light_positions["type"]
      assert_equal 4, light_positions["array_size"]
      assert_equal "uniform3fv", light_positions["setter"]

      camera_block = program["uniform_blocks"].find { |b| b["name"] == "Camera" }
      refute_nil camera_block
      assert_equal "std140", camera_block["layout"]
      assert_equal 0, camera_block["binding"]
      assert_equal %w[vertex fragment], camera_block["stages"]
    end
  end

  def test_glslkit_reflect_runs_standalone_without_a_full_precompile
    Dir.mktmpdir do |public_root|
      stdout, stderr, status = run_in_dummy_app("bin/rails", "glslkit:reflect", env: production_env(public_root))
      assert status.success?, "#{stdout}\n#{stderr}"

      assert manifest_path(public_root).exist?
    end
  end

  def test_glslkit_rails_manifest_reads_the_precompiled_file_in_production
    Dir.mktmpdir do |public_root|
      _, stderr, status = precompile(public_root)
      assert status.success?, stderr

      script = <<~RUBY
        require "json"
        manifest = Glslkit::Rails.manifest
        same_object = Glslkit::Rails.manifest.equal?(manifest)
        puts({programs: manifest["programs"].keys, memoized: same_object}.to_json)
      RUBY
      stdout, stderr, status = run_in_dummy_app("bin/rails", "runner", script, env: production_env(public_root))
      assert status.success?, stderr

      result = JSON.parse(stdout.lines.last)
      assert_equal %w[material pbr], result["programs"].sort
      assert result["memoized"]
    end
  end

  def test_glslkit_rails_manifest_is_rebuilt_live_outside_production
    script = <<~RUBY
      require "json"
      manifest = Glslkit::Rails.manifest
      puts({programs: manifest["programs"].keys}.to_json)
    RUBY
    stdout, stderr, status = run_in_dummy_app("bin/rails", "runner", script, env: {"RAILS_ENV" => "test"})
    assert status.success?, stderr

    result = JSON.parse(stdout.lines.last)
    assert_equal %w[material pbr], result["programs"].sort
  end

  def test_assets_precompile_aborts_on_a_validation_error
    with_broken_shader do
      Dir.mktmpdir do |public_root|
        stdout, stderr, status = precompile(public_root)
        refute status.success?, stdout + stderr
        assert_match(/E006/, stdout + stderr)
        refute manifest_path(public_root).exist?
      end
    end
  end

  def test_glslkit_check_exits_non_zero_on_a_validation_error
    with_broken_shader do
      stdout, stderr, status = run_in_dummy_app("bin/rails", "glslkit:check", env: {"RAILS_ENV" => "test"})
      refute status.success?, stdout + stderr
      assert_match(/E006/, stdout + stderr)
    end
  end

  def test_glslkit_check_succeeds_when_shaders_are_valid
    stdout, stderr, status = run_in_dummy_app("bin/rails", "glslkit:check", env: {"RAILS_ENV" => "test"})
    assert status.success?, stdout + stderr
  end

  private

  # E006(同一ステージ内でのuniform名の重複)を故意に発生させる。テスト後は
  # 必ず削除する(このシェーダ対がprograms検出に残ると他のテストの
  # manifest["programs"]の期待値がずれるため)。
  def with_broken_shader
    vert_path = Pathname.new(DummyAppTestHelper::DUMMY_ROOT).join("app/shaders/broken.vert")
    frag_path = Pathname.new(DummyAppTestHelper::DUMMY_ROOT).join("app/shaders/broken.frag")
    vert_path.write(<<~GLSL)
      in vec3 a_position;
      void main() { gl_Position = vec4(a_position, 1.0); }
    GLSL
    frag_path.write(<<~GLSL)
      uniform float u_x;
      uniform vec3 u_x;
      out vec4 fragColor;
      void main() { fragColor = vec4(1.0); }
    GLSL
    yield
  ensure
    vert_path.delete if vert_path.exist?
    frag_path.delete if frag_path.exist?
  end

  def production_env(public_root)
    {"RAILS_ENV" => "production", "SECRET_KEY_BASE" => "x" * 64, "GLSLKIT_TEST_PUBLIC_ROOT" => public_root}
  end

  def precompile(public_root)
    run_in_dummy_app("bin/rails", "assets:precompile", env: production_env(public_root))
  end

  def manifest_path(public_root)
    Pathname.new(public_root).join("assets", "glsl-manifest.json")
  end

  def read_manifest(public_root)
    JSON.parse(File.read(manifest_path(public_root)))
  end
end
