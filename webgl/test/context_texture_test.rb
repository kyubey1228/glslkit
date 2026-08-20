# frozen_string_literal: true

require "test_helper"

class WebglContextTextureTest < Minitest::Test
  include WebglFixtures

  def setup
    JS.global.reset_frames
    # M10e: warn_missing_generator_onceはプロセス内で1回だけを保証するための
    # クラスインスタンス変数を持つ。テスト間で状態が漏れて順序依存に
    # ならないよう、公開APIを増やさずinstance_variable_setで直接リセットする。
    Glslkit::WebGL::Context.instance_variable_set(:@warned_missing_generator, false)
  end

  def test_context_builds_named_program_and_draws_arrays
    gl = FakeGL.new
    context = Glslkit::WebGL::Context.new(gl, fake_canvas)
    manifest = {
      "generator" => "test-fixture",
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

  def test_program_warns_once_when_the_manifest_has_no_generator_field
    gl = FakeGL.new
    context = Glslkit::WebGL::Context.new(gl, fake_canvas)
    manifest = {"programs" => {"basic" => manifest_program}}

    _stdout, stderr = capture_io do
      context.program(manifest, "basic", vertex: "vertex", fragment: "fragment")
    end

    assert_match(/generator/, stderr)
    assert_match(/rake glslkit:embed/, stderr)
  end

  def test_program_warns_only_once_per_process_even_across_multiple_calls
    gl = FakeGL.new
    context = Glslkit::WebGL::Context.new(gl, fake_canvas)
    manifest = {"programs" => {"a" => manifest_program, "b" => manifest_program}}

    _stdout, first_stderr = capture_io do
      context.program(manifest, "a", vertex: "vertex", fragment: "fragment")
    end
    _stdout, second_stderr = capture_io do
      context.program(manifest, "b", vertex: "vertex", fragment: "fragment")
    end

    refute_empty first_stderr
    assert_empty second_stderr
  end

  def test_program_does_not_warn_when_the_manifest_has_a_generator_field
    gl = FakeGL.new
    context = Glslkit::WebGL::Context.new(gl, fake_canvas)
    manifest = {"generator" => "glslkit/0.1.0", "programs" => {"basic" => manifest_program}}

    _stdout, stderr = capture_io do
      context.program(manifest, "basic", vertex: "vertex", fragment: "fragment")
    end

    assert_empty stderr
  end

  def test_width_and_height_read_from_the_canvas_element
    context = Glslkit::WebGL::Context.new(FakeGL.new, fake_canvas(width: 320, height: 240))

    assert_equal 320, context.width
    assert_equal 240, context.height
  end

  def test_viewport_defaults_to_the_canvas_size
    gl = FakeGL.new
    context = Glslkit::WebGL::Context.new(gl, fake_canvas(width: 320, height: 240))

    assert_same context, context.viewport
    assert_equal [:viewport, 0, 0, 320, 240], gl.calls.first
  end

  def test_viewport_still_accepts_explicit_dimensions
    gl = FakeGL.new
    context = Glslkit::WebGL::Context.new(gl, fake_canvas(width: 320, height: 240))

    context.viewport(64, 48, x: 1, y: 2)

    assert_equal [:viewport, 1, 2, 64, 48], gl.calls.first
  end

  def test_texture_uploads_static_rgba_pixels
    gl = FakeGL.new
    context = Glslkit::WebGL::Context.new(gl, fake_canvas)

    texture = context.texture2d(width: 1, height: 1, data: [255, 0, 0, 255], unit: 2)

    assert_equal 2, texture.unit
    assert_includes gl.calls.map(&:first), :texImage2D
    assert_same texture, texture.bind
  end

  def test_loop_passes_elapsed_seconds_and_reregisters
    context = Glslkit::WebGL::Context.new(FakeGL.new, fake_canvas)
    elapsed = []

    tick = context.loop { |seconds| elapsed << seconds }
    JS.global.next_frame(350.0)

    assert_kind_of Proc, tick
    assert_equal [0.25], elapsed
  end

  def test_debug_mode_checks_gl_error_once_at_frame_end
    gl = FakeGL.new
    context = Glslkit::WebGL::Context.new(gl, fake_canvas)
    Glslkit::WebGL.debug = true
    context.loop { nil }

    JS.global.next_frame(400.0)

    assert_equal 1, gl.calls.count { |call| call.first == :getError }
  ensure
    Glslkit::WebGL.debug = false
  end
end
