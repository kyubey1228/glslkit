# frozen_string_literal: true

require "test_helper"

class ValidatorTest < Minitest::Test
  def process(code, filename)
    resolver = Glslkit::Resolvers::Hash.new(filename => code)
    Glslkit::Preprocessor.new(resolver: resolver).process(filename)
  end

  def build_program(name, vertex: nil, fragment: nil)
    sources = {}
    sources[:vertex] = process(vertex, "#{name}.vert") if vertex
    sources[:fragment] = process(fragment, "#{name}.frag") if fragment
    Glslkit::Program.new(name: name, sources: sources)
  end

  def validate(program, **opts)
    Glslkit::Validator.new(**opts).validate(program)
  end

  # --- E001: vertex out / fragment in type mismatch ---

  def test_e001_detects_a_type_mismatch_between_vertex_out_and_fragment_in
    vertex = <<~GLSL
      out vec3 v_uv;
      void main() {}
    GLSL
    fragment = <<~GLSL
      in vec2 v_uv;
      out vec4 fragColor;
      void main() {}
    GLSL

    result = validate(build_program("p", vertex: vertex, fragment: fragment))

    diagnostic = result.errors.find { |d| d.code == "E001" }
    refute_nil diagnostic
    assert_equal :fragment, diagnostic.stage
    assert_includes diagnostic.message, "vec3"
    assert_includes diagnostic.message, "vec2"
  end

  def test_e001_does_not_flag_matching_types
    vertex = <<~GLSL
      out vec3 v_uv;
      void main() {}
    GLSL
    fragment = <<~GLSL
      in vec3 v_uv;
      out vec4 fragColor;
      void main() {}
    GLSL

    result = validate(build_program("p", vertex: vertex, fragment: fragment))

    assert_empty result.diagnostics.select { |d| d.code == "E001" }
  end

  # --- E002: fragment in with no matching vertex out (warning) ---

  def test_e002_detects_a_fragment_in_with_no_matching_vertex_out
    vertex = "void main() {}\n"
    fragment = <<~GLSL
      in vec2 v_uv;
      out vec4 fragColor;
      void main() {}
    GLSL

    result = validate(build_program("p", vertex: vertex, fragment: fragment))

    diagnostic = result.warnings.find { |d| d.code == "E002" }
    refute_nil diagnostic
    assert_equal :fragment, diagnostic.stage
    assert_includes diagnostic.message, "v_uv"
  end

  def test_e002_is_skipped_when_a_stage_is_missing
    fragment = <<~GLSL
      in vec2 v_uv;
      out vec4 fragColor;
      void main() {}
    GLSL

    result = validate(build_program("p", fragment: fragment))

    assert_empty result.diagnostics.select { |d| d.code == "E002" }
  end

  # --- W001: vertex out with no matching fragment in (warning) ---

  def test_w001_detects_a_vertex_out_with_no_matching_fragment_in
    vertex = <<~GLSL
      out vec3 v_normal;
      void main() {}
    GLSL
    fragment = "out vec4 fragColor;\nvoid main() {}\n"

    result = validate(build_program("p", vertex: vertex, fragment: fragment))

    diagnostic = result.warnings.find { |d| d.code == "W001" }
    refute_nil diagnostic
    assert_equal :vertex, diagnostic.stage
    assert_includes diagnostic.message, "v_normal"
  end

  def test_w001_is_skipped_when_a_stage_is_missing
    vertex = <<~GLSL
      out vec3 v_normal;
      void main() {}
    GLSL

    result = validate(build_program("p", vertex: vertex))

    assert_empty result.diagnostics.select { |d| d.code == "W001" }
  end

  # --- E003: cross-stage uniform / uniform block mismatch ---

  def test_e003_detects_a_cross_stage_uniform_type_mismatch
    vertex = "uniform mat4 u_thing;\nvoid main() {}\n"
    fragment = "uniform vec4 u_thing;\nout vec4 fragColor;\nvoid main() {}\n"

    result = validate(build_program("p", vertex: vertex, fragment: fragment))

    diagnostic = result.errors.find { |d| d.code == "E003" }
    refute_nil diagnostic
    assert_equal :fragment, diagnostic.stage
    assert_includes diagnostic.message, "u_thing"
  end

  def test_e003_detects_a_cross_stage_uniform_block_mismatch
    vertex = <<~GLSL
      layout(std140, binding = 0) uniform Camera { mat4 view; };
      void main() {}
    GLSL
    fragment = <<~GLSL
      layout(std430, binding = 1) uniform Camera { mat4 view; };
      out vec4 fragColor;
      void main() {}
    GLSL

    result = validate(build_program("p", vertex: vertex, fragment: fragment))

    diagnostic = result.errors.find { |d| d.code == "E003" }
    refute_nil diagnostic
    assert_equal :fragment, diagnostic.stage
    assert_includes diagnostic.message, "Camera"
  end

  def test_e003_does_not_flag_a_consistent_uniform_or_block
    vertex = <<~GLSL
      uniform mat4 u_mvp;
      layout(std140, binding = 0) uniform Camera { mat4 view; };
      void main() {}
    GLSL
    fragment = <<~GLSL
      uniform mat4 u_mvp;
      layout(std140, binding = 0) uniform Camera { mat4 view; };
      out vec4 fragColor;
      void main() {}
    GLSL

    result = validate(build_program("p", vertex: vertex, fragment: fragment))

    assert_empty result.diagnostics.select { |d| d.code == "E003" }
  end

  def test_e003_is_skipped_when_a_stage_is_missing
    fragment = "uniform vec4 u_thing;\nout vec4 fragColor;\nvoid main() {}\n"

    result = validate(build_program("p", fragment: fragment))

    assert_empty result.diagnostics.select { |d| d.code == "E003" }
  end

  # --- E004: attribute location duplicated (vertex-only) ---

  def test_e004_detects_duplicate_attribute_locations
    vertex = <<~GLSL
      layout(location = 0) in vec3 a_position;
      layout(location = 0) in vec3 a_normal;
      void main() {}
    GLSL

    result = validate(build_program("p", vertex: vertex))

    diagnostic = result.errors.find { |d| d.code == "E004" }
    refute_nil diagnostic
    assert_equal :vertex, diagnostic.stage
    assert_includes diagnostic.message, "a_position"
    assert_includes diagnostic.message, "a_normal"
  end

  def test_e004_does_not_flag_distinct_or_unspecified_locations
    vertex = <<~GLSL
      layout(location = 0) in vec3 a_position;
      layout(location = 1) in vec3 a_normal;
      in vec2 a_uv;
      void main() {}
    GLSL

    result = validate(build_program("p", vertex: vertex))

    assert_empty result.errors.select { |d| d.code == "E004" }
  end

  # --- E005: output location duplicated (fragment-only) ---

  def test_e005_detects_duplicate_output_locations
    fragment = <<~GLSL
      layout(location = 0) out vec4 a;
      layout(location = 0) out vec4 b;
      void main() {}
    GLSL

    result = validate(build_program("p", fragment: fragment))

    diagnostic = result.errors.find { |d| d.code == "E005" }
    refute_nil diagnostic
    assert_equal :fragment, diagnostic.stage
    assert_includes diagnostic.message, "a"
    assert_includes diagnostic.message, "b"
  end

  def test_e005_does_not_flag_distinct_or_unspecified_locations
    fragment = <<~GLSL
      layout(location = 0) out vec4 a;
      layout(location = 1) out vec4 b;
      out vec4 c;
      void main() {}
    GLSL

    result = validate(build_program("p", fragment: fragment))

    assert_empty result.errors.select { |d| d.code == "E005" }
  end

  # --- E006: duplicate name within a single stage ---

  def test_e006_detects_the_same_uniform_declared_twice_in_one_stage
    fragment = <<~GLSL
      uniform float u_x;
      uniform vec3 u_x;
      out vec4 fragColor;
      void main() {}
    GLSL

    result = validate(build_program("p", fragment: fragment))

    diagnostic = result.errors.find { |d| d.code == "E006" }
    refute_nil diagnostic
    assert_equal :fragment, diagnostic.stage
    assert_includes diagnostic.message, "u_x"
  end

  def test_e006_detects_cross_kind_name_collisions
    fragment = <<~GLSL
      uniform vec3 Camera;
      layout(std140) uniform Camera {
        mat4 view;
      };
      out vec4 fragColor;
      void main() {}
    GLSL

    result = validate(build_program("p", fragment: fragment))

    assert(result.errors.any? { |d| d.code == "E006" && d.message.include?("Camera") })
  end

  def test_e006_does_not_flag_unique_names
    fragment = <<~GLSL
      uniform float u_a;
      uniform float u_b;
      out vec4 fragColor;
      void main() {}
    GLSL

    result = validate(build_program("p", fragment: fragment))

    assert_empty result.errors.select { |d| d.code == "E006" }
  end

  # --- E007: reserved gl_ prefix ---

  def test_e007_detects_a_reserved_gl_prefix
    fragment = <<~GLSL
      uniform vec3 gl_Custom;
      out vec4 fragColor;
      void main() {}
    GLSL

    result = validate(build_program("p", fragment: fragment))

    diagnostic = result.errors.find { |d| d.code == "E007" }
    refute_nil diagnostic
    assert_equal "gl_Custom", diagnostic.name
  end

  def test_e007_does_not_flag_ordinary_names
    fragment = <<~GLSL
      uniform vec3 u_color;
      out vec4 fragColor;
      void main() {}
    GLSL

    result = validate(build_program("p", fragment: fragment))

    assert_empty result.errors.select { |d| d.code == "E007" }
  end

  # --- cross-cutting behaviour ---

  def test_a_clean_program_has_no_diagnostics
    vertex = <<~GLSL
      layout(location = 0) in vec3 a_position;
      uniform mat4 u_model_view;
      void main() { gl_Position = u_model_view * vec4(a_position, 1.0); }
    GLSL
    fragment = <<~GLSL
      out vec4 fragColor;
      void main() { fragColor = vec4(1.0); }
    GLSL

    result = validate(build_program("p", vertex: vertex, fragment: fragment))

    assert_empty result.diagnostics
    assert result.ok?
  end

  def test_collects_violations_from_multiple_rules_and_both_stages_in_one_call
    vertex = <<~GLSL
      layout(location = 0) in vec3 a_position;
      layout(location = 0) in vec3 a_normal;
      void main() {}
    GLSL
    fragment = <<~GLSL
      uniform vec3 gl_bad;
      layout(location = 0) out vec4 a;
      layout(location = 0) out vec4 b;
      void main() {}
    GLSL

    result = validate(build_program("p", vertex: vertex, fragment: fragment))

    assert_equal %w[E004 E005 E007], result.errors.map(&:code).sort
  end

  def test_disabled_option_suppresses_a_rule
    vertex = <<~GLSL
      layout(location = 0) in vec3 a_position;
      layout(location = 0) in vec3 a_normal;
      void main() {}
    GLSL

    result = validate(build_program("p", vertex: vertex), disabled: ["E004"])

    assert_empty result.errors
  end

  def test_diagnostics_resolve_file_and_line_from_the_owning_stages_own_source_map
    vertex = <<~GLSL
      layout(location = 0) in vec3 a_position;
      layout(location = 0) in vec3 a_normal;
      void main() {}
    GLSL
    fragment = <<~GLSL
      layout(location = 0) out vec4 a;
      layout(location = 0) out vec4 b;
      void main() {}
    GLSL

    result = validate(build_program("p", vertex: vertex, fragment: fragment))

    vertex_diagnostic = result.errors.find { |d| d.code == "E004" }
    fragment_diagnostic = result.errors.find { |d| d.code == "E005" }

    assert_equal "p.vert", vertex_diagnostic.file
    assert_equal 1, vertex_diagnostic.line
    assert_equal "p.frag", fragment_diagnostic.file
    assert_equal 1, fragment_diagnostic.line
  end

  def test_validation_completes_without_a_source_map
    vertex_source = process("layout(location = 0) in vec3 a_position;\n" \
      "layout(location = 0) in vec3 a_normal;\nvoid main() {}\n", "p.vert")
    bare_source = Glslkit::Source.new(
      code: vertex_source.code, reflection: vertex_source.reflection, source_map: nil, digest: vertex_source.digest
    )
    program = Glslkit::Program.new(name: "p", sources: {vertex: bare_source})

    result = validate(program)

    diagnostic = result.errors.find { |d| d.code == "E004" }
    refute_nil diagnostic
    assert_nil diagnostic.file
    assert_nil diagnostic.line
  end

  def test_validation_completes_when_resolve_cannot_find_a_segment
    vertex_source = process("layout(location = 0) in vec3 a_position;\n" \
      "layout(location = 0) in vec3 a_normal;\nvoid main() {}\n", "p.vert")
    empty_map = Glslkit::SourceMap.new # no add_segment calls at all: resolve always returns nil
    source_without_resolvable_segments = Glslkit::Source.new(
      code: vertex_source.code, reflection: vertex_source.reflection, source_map: empty_map,
      digest: vertex_source.digest
    )
    program = Glslkit::Program.new(name: "p", sources: {vertex: source_without_resolvable_segments})

    result = validate(program)

    diagnostic = result.errors.find { |d| d.code == "E004" }
    refute_nil diagnostic
    assert_nil diagnostic.file
    assert_nil diagnostic.line
  end
end
