# frozen_string_literal: true

require "test_helper"
require "json"
require "json_schemer"

class ManifestBuildTest < Minitest::Test
  SCHEMA_PATH = File.expand_path("../../../spec/schema/reflection-v1.json", __dir__)

  def process(code, filename)
    resolver = Glslkit::Resolvers::Hash.new(filename => code)
    Glslkit::Preprocessor.new(resolver: resolver).process(filename)
  end

  def test_builds_a_schema_valid_manifest_from_programs
    vertex = process("layout(location = 0) in vec3 a_position;\nuniform mat4 u_mvp;\nvoid main() {}\n", "pbr.vert")
    fragment = process("uniform sampler2D u_albedo;\nout vec4 fragColor;\nvoid main() {}\n", "pbr.frag")
    program = Glslkit::Program.new(name: "pbr", sources: {vertex: vertex, fragment: fragment})

    manifest = Glslkit::Manifest.build(
      programs: [program],
      urls: {"pbr" => {vertex: "/assets/pbr-a1b2.vert", fragment: "/assets/pbr-c3d4.frag"}},
      now: Time.at(1_755_400_000)
    )

    schema = JSONSchemer.schema(JSON.parse(File.read(SCHEMA_PATH)))
    manifest_json = JSON.parse(JSON.generate(manifest))
    assert schema.valid?(manifest_json), schema.validate(manifest_json).to_a.inspect

    program_hash = manifest["programs"]["pbr"]
    assert_equal "pbr.vert", program_hash["stages"]["vertex"]["path"]
    assert_equal "/assets/pbr-a1b2.vert", program_hash["stages"]["vertex"]["url"]
    assert_equal "pbr.frag", program_hash["stages"]["fragment"]["path"]
  end

  def test_skips_programs_that_are_missing_a_stage
    fragment = process("out vec4 fragColor;\nvoid main() {}\n", "partial.frag")
    program = Glslkit::Program.new(name: "partial", sources: {fragment: fragment})

    manifest = Glslkit::Manifest.build(programs: [program])

    assert_empty manifest["programs"]
  end

  def test_still_raises_stage_mismatch_error_for_unvalidated_input
    vertex = process("uniform mat4 u_thing;\nvoid main() {}\n", "a.vert")
    fragment = process("uniform vec4 u_thing;\nvoid main() {}\n", "a.frag")
    program = Glslkit::Program.new(name: "a", sources: {vertex: vertex, fragment: fragment})

    assert_raises(Glslkit::StageMismatchError) { Glslkit::Manifest.build(programs: [program]) }
  end
end
