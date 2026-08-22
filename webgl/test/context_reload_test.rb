# frozen_string_literal: true

require "test_helper"

class WebglContextReloadTest < Minitest::Test
  include WebglFixtures

  POSITION_ATTRIBUTE = {"name" => "a_position", "type" => "vec2", "location" => 0, "array_size" => 1}.freeze

  def setup
    JS.global.reset_frames
    Glslkit::WebGL::Context.instance_variable_set(:@warned_missing_generator, false)
  end

  def manifest_with(attributes: [POSITION_ATTRIBUTE], uniforms: [])
    {"generator" => "test-fixture", "programs" => {"neon" => manifest_program(attributes: attributes, uniforms: uniforms)}}
  end

  def build_context_with_geometry(gl, attributes: [POSITION_ATTRIBUTE], uniforms: [])
    context = Glslkit::WebGL::Context.new(gl, fake_canvas)
    program = context.program(manifest_with(attributes: attributes, uniforms: uniforms), "neon", vertex: "v", fragment: "f")
    geometry = context.geometry(
      program: program, attributes: {a_position: {data: [0, 0, 1, 0, 0, 1], components: 2}}
    )
    [context, program, geometry]
  end

  def test_reload_succeeds_and_keeps_the_existing_vao_when_locations_match
    gl = FakeGL.new
    context, old_program, geometry = build_context_with_geometry(gl)
    old_vao = geometry.vao

    result = context.reload_program("neon", vertex: "v2", fragment: "f2", manifest: manifest_with)

    assert result.ok?
    assert_empty result.diagnostics
    assert_same old_vao, geometry.vao # Geometryはreloadで一切触られない

    calls_before = gl.calls.size
    assert_same context, context.draw(geometry)
    draw_calls = gl.calls[calls_before..]
    assert_includes draw_calls.map(&:first), :bindVertexArray
    assert_includes draw_calls.map(&:first), :drawArrays
    refute_same old_program, context.instance_variable_get(:@current_program)
  end

  def test_reload_raises_when_an_attribute_location_changes
    gl = FakeGL.new
    context, = build_context_with_geometry(gl)
    moved_attribute = POSITION_ATTRIBUTE.merge("location" => 1)

    error = assert_raises(Glslkit::WebGL::ReloadIncompatibleError) do
      context.reload_program("neon", vertex: "v2", fragment: "f2", manifest: manifest_with(attributes: [moved_attribute]))
    end
    assert_match(/a_position/, error.message)
  end

  def test_compile_failure_raises_and_the_old_program_keeps_drawing
    gl = FakeGL.new
    context, old_program, geometry = build_context_with_geometry(gl)

    gl.shader_ok = false
    gl.shader_log = "ERROR: 0:1: broken"
    assert_raises(Glslkit::WebGL::CompileError) do
      context.reload_program("neon", vertex: "broken", fragment: "f2", manifest: manifest_with)
    end

    gl.shader_ok = true
    calls_before = gl.calls.size
    assert_same context, context.draw(geometry, program: old_program)
    draw_calls = gl.calls[calls_before..]
    assert_includes draw_calls.map(&:first), :drawArrays
  end

  def test_link_failure_raises_and_the_old_program_keeps_drawing
    gl = FakeGL.new
    context, old_program, geometry = build_context_with_geometry(gl)

    gl.program_ok = false
    gl.program_log = "varyings do not match"
    assert_raises(Glslkit::WebGL::LinkError) do
      context.reload_program("neon", vertex: "v2", fragment: "f2", manifest: manifest_with)
    end

    gl.program_ok = true
    calls_before = gl.calls.size
    assert_same context, context.draw(geometry, program: old_program)
    draw_calls = gl.calls[calls_before..]
    assert_includes draw_calls.map(&:first), :drawArrays
  end

  def test_reload_restores_a_uniform_value_when_the_type_matches
    gl = FakeGL.new
    context, old_program, = build_context_with_geometry(gl, uniforms: [uniform(name: "u_color", setter: "uniform4fv", count: 4)])
    old_program.set(:u_color, [1, 0, 0, 1])

    calls_before = gl.calls.size
    result = context.reload_program(
      "neon", vertex: "v2", fragment: "f2",
      manifest: manifest_with(uniforms: [uniform(name: "u_color", setter: "uniform4fv", count: 4)])
    )

    assert result.ok?
    assert_empty result.diagnostics
    restore_calls = gl.calls[calls_before..].select { |call| call.first == :uniform4fv }
    assert_equal 1, restore_calls.size
    assert_equal [1, 0, 0, 1], restore_calls.first[2].values
  end

  def test_reload_discards_a_uniform_removed_from_the_new_shader
    gl = FakeGL.new
    context, old_program, = build_context_with_geometry(gl, uniforms: [uniform(name: "u_color", setter: "uniform4fv", count: 4)])
    old_program.set(:u_color, [1, 0, 0, 1])

    result = context.reload_program("neon", vertex: "v2", fragment: "f2", manifest: manifest_with)

    assert result.ok?
    diagnostic = result.diagnostics.find { |d| d.name == "u_color" }
    refute_nil diagnostic
    assert_equal :warning, diagnostic.severity
    assert_match(/no longer exists/, diagnostic.message)
  end

  def test_reload_discards_a_uniform_whose_type_changed
    gl = FakeGL.new
    context, old_program, = build_context_with_geometry(gl, uniforms: [uniform(name: "u_color", setter: "uniform4fv", count: 4)])
    old_program.set(:u_color, [1, 0, 0, 1])
    changed_type_uniform = uniform(name: "u_color", setter: "uniform3fv", count: 3).merge("type" => "vec3")

    result = context.reload_program("neon", vertex: "v2", fragment: "f2", manifest: manifest_with(uniforms: [changed_type_uniform]))

    assert result.ok?
    diagnostic = result.diagnostics.find { |d| d.name == "u_color" }
    refute_nil diagnostic
    assert_match(/changed type/, diagnostic.message)
  end

  def test_reload_discards_a_uniform_whose_element_count_changed
    gl = FakeGL.new
    array_uniform = uniform(name: "u_positions", setter: "uniform3fv", count: 3).merge("type" => "vec3")
    context, old_program, = build_context_with_geometry(gl, uniforms: [array_uniform])
    old_program.set(:u_positions, [1, 2, 3])
    grown_uniform = array_uniform.merge("element_count" => 6)

    result = context.reload_program("neon", vertex: "v2", fragment: "f2", manifest: manifest_with(uniforms: [grown_uniform]))

    assert result.ok?
    diagnostic = result.diagnostics.find { |d| d.name == "u_positions" }
    refute_nil diagnostic
    assert_match(/changed type/, diagnostic.message)
  end

  def test_reload_raises_unknown_program_error_for_an_untracked_name
    gl = FakeGL.new
    context = Glslkit::WebGL::Context.new(gl, fake_canvas)

    assert_raises(Glslkit::WebGL::UnknownProgramError) do
      context.reload_program("ghost", vertex: "v", fragment: "f", manifest: manifest_with)
    end
  end
end
