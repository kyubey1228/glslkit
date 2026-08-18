# frozen_string_literal: true

require "test_helper"

class WebglContextTextureTest < Minitest::Test
  include WebglFixtures

  def setup
    JS.global.reset_frames
  end

  def test_context_builds_named_program_and_draws_arrays
    gl = FakeGL.new
    context = Glslkit::WebGL::Context.new(gl)
    manifest = {
      "programs" => {
        "basic" => manifest_program(attributes: [
          {"name" => "a_position", "type" => "vec2", "location" => 0, "array_size" => 1}
        ])
      }
    }
    program = context.program(manifest, "basic", vertex: "vertex", fragment: "fragment")
    geometry = context.geometry(
      program: program,
      attributes: {a_position: {data: [0, 0, 1, 0, 0, 1], components: 2}}
    )

    assert_same context, context.draw(geometry, program: program)
    names = gl.calls.map(&:first)
    assert_includes names, :useProgram
    assert_includes names, :drawArrays
  end

  def test_texture_uploads_static_rgba_pixels
    gl = FakeGL.new
    context = Glslkit::WebGL::Context.new(gl)

    texture = context.texture2d(width: 1, height: 1, data: [255, 0, 0, 255], unit: 2)

    assert_equal 2, texture.unit
    assert_includes gl.calls.map(&:first), :texImage2D
    assert_same texture, texture.bind
  end

  def test_loop_passes_elapsed_seconds_and_reregisters
    context = Glslkit::WebGL::Context.new(FakeGL.new)
    elapsed = []

    tick = context.loop { |seconds| elapsed << seconds }
    JS.global.next_frame(350.0)

    assert_kind_of Proc, tick
    assert_equal [0.25], elapsed
  end

  def test_debug_mode_checks_gl_error_once_at_frame_end
    gl = FakeGL.new
    context = Glslkit::WebGL::Context.new(gl)
    Glslkit::WebGL.debug = true
    context.loop { nil }

    JS.global.next_frame(400.0)

    assert_equal 1, gl.calls.count { |call| call.first == :getError }
  ensure
    Glslkit::WebGL.debug = false
  end
end
