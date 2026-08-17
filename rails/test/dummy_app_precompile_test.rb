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
      assert_equal ["pbr"], result["programs"]
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
    assert_equal ["pbr"], result["programs"]
  end

  private

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
