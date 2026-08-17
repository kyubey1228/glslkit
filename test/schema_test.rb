# frozen_string_literal: true

require "json"
require "json_schemer"
require "minitest/autorun"

class ReflectionSchemaTest < Minitest::Test
  SCHEMA_PATH = File.expand_path("../spec/schema/reflection-v1.json", __dir__)

  def setup
    @schema_json = JSON.parse(File.read(SCHEMA_PATH))
    @schemer = JSONSchemer.schema(@schema_json)
  end

  def test_schema_file_is_valid_json
    assert_kind_of Hash, @schema_json
  end

  def test_schema_itself_conforms_to_draft_2020_12
    assert @schemer.valid_schema?, @schemer.validate_schema.to_a.inspect
  end

  def test_valid_manifest_passes
    assert_valid valid_manifest
  end

  def test_missing_fragment_stage_fails
    manifest = valid_manifest
    manifest["programs"]["pbr"]["stages"].delete("fragment")

    refute_valid manifest
  end

  def test_wrong_schema_version_fails
    manifest = valid_manifest
    manifest["schema_version"] = 2

    refute_valid manifest
  end

  def test_non_hex_digest_fails
    manifest = valid_manifest
    manifest["programs"]["pbr"]["digest"] = "not-a-digest"

    refute_valid manifest
  end

  def test_negative_location_fails
    manifest = valid_manifest
    manifest["programs"]["pbr"]["attributes"][0]["location"] = -1

    refute_valid manifest
  end

  def test_array_size_below_one_fails
    manifest = valid_manifest
    manifest["programs"]["pbr"]["uniforms"][2]["array_size"] = 0

    refute_valid manifest
  end

  def test_unknown_top_level_key_fails
    manifest = valid_manifest
    manifest["unexpected"] = true

    refute_valid manifest
  end

  private

  def assert_valid(manifest)
    assert @schemer.valid?(manifest), @schemer.validate(manifest).to_a.inspect
  end

  def refute_valid(manifest)
    refute @schemer.valid?(manifest)
  end

  # Mirrors the "pbr" example from SPEC.md §3, round-tripped through JSON so
  # keys/values match what Glslkit::Manifest will actually produce.
  def valid_manifest
    JSON.parse(JSON.generate({
      schema_version: 1,
      generated_at: "2026-08-17T00:00:00Z",
      programs: {
        pbr: {
          digest: "3f9a#{"0" * 60}",
          stages: {
            vertex: {path: "pbr.vert", digest: "a1b2#{"0" * 60}", url: "/assets/pbr-a1b2.vert"},
            fragment: {path: "pbr.frag", digest: "c3d4#{"0" * 60}", url: "/assets/pbr-c3d4.frag"}
          },
          attributes: [
            {name: "a_position", type: "vec3", location: 0, array_size: 1},
            {name: "a_uv", type: "vec2", location: nil, array_size: 1}
          ],
          uniforms: [
            {name: "u_model_view", type: "mat4", array_size: 1,
             setter: "uniformMatrix4fv", matrix: true, sampler: false, stages: ["vertex"]},
            {name: "u_albedo", type: "sampler2D", array_size: 1,
             setter: "uniform1iv", matrix: false, sampler: true, stages: ["fragment"]},
            {name: "u_lights", type: "vec4", array_size: 8,
             setter: "uniform4fv", matrix: false, sampler: false, stages: ["fragment"]}
          ],
          uniform_blocks: [
            {name: "Camera", layout: "std140", binding: 0, stages: ["vertex", "fragment"]}
          ],
          outputs: [
            {name: "fragColor", type: "vec4", location: 0}
          ]
        }
      }
    }))
  end
end
