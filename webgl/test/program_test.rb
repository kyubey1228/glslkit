# frozen_string_literal: true

require "test_helper"

class WebglProgramTest < Minitest::Test
  include WebglFixtures

  def test_compiles_and_links_without_active_reflection_calls
    gl = FakeGL.new
    program = Glslkit::WebGL::Program.new(gl, manifest_program,
      vertex: "vertex", fragment: "fragment")

    assert program.handle
    names = gl.calls.map(&:first)
    assert_equal 2, names.count(:compileShader)
    assert_includes names, :linkProgram
    refute_includes names, :getActiveUniform
    refute_includes names, :getActiveAttrib
  end

  def test_compile_error_resolves_original_source_location
    gl = FakeGL.new
    gl.shader_ok = false
    gl.shader_log = "ERROR: 0:7: ';' : syntax error"
    source_map = Glslkit::SourceMap.new
    index = source_map.index_for("common/math.glsl")
    source_map.add_segment(output_line: 5, file_index: index, source_line: 10)

    error = assert_raises(Glslkit::WebGL::CompileError) do
      Glslkit::WebGL::Program.new(gl, manifest_program,
        vertex: "broken", fragment: "fragment", source_maps: {vertex: source_map})
    end

    assert_equal :vertex, error.stage
    assert_equal "common/math.glsl", error.file
    assert_equal 12, error.line
    assert_equal "ERROR: 0:7: ';' : syntax error", error.raw_log
    assert_equal "common/math.glsl:12: ';' : syntax error", error.message
  end

  def test_unparseable_compile_log_still_raises_with_raw_log
    gl = FakeGL.new
    gl.shader_ok = false
    gl.shader_log = "driver said no"

    error = assert_raises(Glslkit::WebGL::CompileError) do
      Glslkit::WebGL::Program.new(gl, manifest_program,
        vertex: "broken", fragment: "fragment")
    end

    assert_nil error.file
    assert_nil error.line
    assert_equal "driver said no", error.message
  end

  def test_link_error_preserves_raw_log
    gl = FakeGL.new
    gl.program_ok = false
    gl.program_log = "varyings do not match"

    error = assert_raises(Glslkit::WebGL::LinkError) do
      Glslkit::WebGL::Program.new(gl, manifest_program,
        vertex: "vertex", fragment: "fragment")
    end

    assert_equal "varyings do not match", error.raw_log
  end

  def test_uniform_buffer_is_reused_and_length_is_validated
    gl = FakeGL.new
    program = Glslkit::WebGL::Program.new(gl,
      manifest_program(uniforms: [uniform]), vertex: "vertex", fragment: "fragment")

    program.set(:u_color, [1, 0, 0, 1])
    program.set(:u_color, [0, 1, 0, 1])
    calls = gl.calls.select { |call| call.first == :uniform4fv }
    assert_same calls[0][2], calls[1][2]
    assert_equal [0, 1, 0, 1], calls[1][2].values
    assert_equal 1, gl.calls.count { |call| call.first == :useProgram }

    error = assert_raises(Glslkit::WebGL::UniformLengthError) do
      program.set(:u_color, [1, 2])
    end
    assert_includes error.message, "expects 4 elements, got 2"
  end

  def test_null_uniform_location_is_silently_ignored
    gl = FakeGL.new
    gl.uniform_locations["u_color"] = JS::Null
    program = Glslkit::WebGL::Program.new(gl,
      manifest_program(uniforms: [uniform]), vertex: "vertex", fragment: "fragment")

    assert_same program, program.set(:u_color, [1, 2, 3, 4])
    refute gl.calls.any? { |call| call.first == :uniform4fv }
  end

  def test_unknown_uniform_raises
    program = Glslkit::WebGL::Program.new(FakeGL.new, manifest_program,
      vertex: "vertex", fragment: "fragment")

    assert_raises(Glslkit::WebGL::UnknownUniformError) { program.set(:typo, 1) }
  end
end
