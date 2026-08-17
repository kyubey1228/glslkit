# frozen_string_literal: true

require "test_helper"
require "json"
require "json_schemer"

class ManifestTest < Minitest::Test
  SCHEMA_PATH = File.expand_path("../../../spec/schema/reflection-v1.json", __dir__)

  VERTEX = <<~GLSL
    #version 300 es
    layout(location = 0) in vec3 a_position;
    uniform mat4 u_view;
    layout(std140, binding = 0) uniform Camera {
      mat4 view;
    };
    out vec3 v_normal;
    void main() {
      gl_Position = u_view * vec4(a_position, 1.0);
    }
  GLSL

  FRAGMENT = <<~GLSL
    #version 300 es
    precision mediump float;
    in vec3 v_normal;
    uniform mat4 u_view;
    uniform sampler2D u_albedo;
    layout(std140, binding = 0) uniform Camera {
      mat4 view;
    };
    out vec4 fragColor;
    void main() {
      fragColor = texture(u_albedo, vec2(0.0));
    }
  GLSL

  def process(code, name)
    resolver = Glslkit::Resolvers::Hash.new(name => code)
    Glslkit::Preprocessor.new(resolver: resolver).process(name)
  end

  def build_manifest
    vertex_source = process(VERTEX, "pbr.vert")
    fragment_source = process(FRAGMENT, "pbr.frag")

    manifest = Glslkit::Manifest.new(generated_at: "2026-08-17T00:00:00Z")
    manifest.add_program("pbr",
      vertex: {path: "pbr.vert", source: vertex_source, url: "/assets/pbr-a1b2.vert"},
      fragment: {path: "pbr.frag", source: fragment_source, url: "/assets/pbr-c3d4.frag"})
    manifest
  end

  def test_generated_manifest_matches_the_schema
    schema = JSONSchemer.schema(JSON.parse(File.read(SCHEMA_PATH)))
    manifest_hash = JSON.parse(build_manifest.to_json)

    assert schema.valid?(manifest_hash), schema.validate(manifest_hash).to_a.inspect
  end

  def test_shared_uniform_merges_across_stages
    program = build_manifest.to_h["programs"]["pbr"]
    uniforms_by_name = program["uniforms"].to_h { |u| [u["name"], u] }

    assert_equal %w[vertex fragment], uniforms_by_name.fetch("u_view")["stages"]
    assert_equal ["fragment"], uniforms_by_name.fetch("u_albedo")["stages"]
    assert_equal %w[vertex fragment], program["uniform_blocks"].first["stages"]
  end

  def test_attributes_come_only_from_vertex_and_outputs_only_from_fragment
    program = build_manifest.to_h["programs"]["pbr"]

    assert_equal ["a_position"], program["attributes"].map { |a| a["name"] }
    assert_equal ["fragColor"], program["outputs"].map { |o| o["name"] }
  end

  def test_type_mismatch_raises_stage_mismatch_error
    vertex_source = process("uniform mat4 u_thing;\nvoid main() {}\n", "a.vert")
    fragment_source = process("uniform vec4 u_thing;\nvoid main() {}\n", "a.frag")

    manifest = Glslkit::Manifest.new(generated_at: "2026-08-17T00:00:00Z")

    assert_raises(Glslkit::StageMismatchError) do
      manifest.add_program("a",
        vertex: {path: "a.vert", source: vertex_source, url: "/assets/a.vert"},
        fragment: {path: "a.frag", source: fragment_source, url: "/assets/a.frag"})
    end
  end

  def test_uniform_block_binding_mismatch_raises_stage_mismatch_error
    vertex_source = process("layout(std140, binding = 0) uniform Camera { mat4 v; };\nvoid main() {}\n", "a.vert")
    fragment_source = process("layout(std140, binding = 1) uniform Camera { mat4 v; };\nvoid main() {}\n", "a.frag")

    manifest = Glslkit::Manifest.new(generated_at: "2026-08-17T00:00:00Z")

    assert_raises(Glslkit::StageMismatchError) do
      manifest.add_program("a",
        vertex: {path: "a.vert", source: vertex_source, url: "/assets/a.vert"},
        fragment: {path: "a.frag", source: fragment_source, url: "/assets/a.frag"})
    end
  end

  def test_same_input_produces_the_same_digest_deterministically
    first = build_manifest.to_h["programs"]["pbr"]
    second = build_manifest.to_h["programs"]["pbr"]

    assert_equal first["digest"], second["digest"]
    assert_equal first["stages"]["vertex"]["digest"], second["stages"]["vertex"]["digest"]
    assert_equal first["stages"]["fragment"]["digest"], second["stages"]["fragment"]["digest"]
  end
end
