# frozen_string_literal: true

require "test_helper"
require "glslkit/webgl/live_reload"
require "json"

class WebglLiveReloadTest < Minitest::Test
  include WebglFixtures

  POSITION_ATTRIBUTE = {"name" => "a_position", "type" => "vec2", "location" => 0, "array_size" => 1}.freeze

  def setup
    JS.global.reset_frames
    JS.global.reset_intervals
    JS.global.fetch_handler = nil
    Glslkit::WebGL::Context.instance_variable_set(:@warned_missing_generator, false)
  end

  def manifest_json(name, attributes: [POSITION_ATTRIBUTE])
    {"generator" => "test-fixture", "programs" => {name => manifest_program(attributes: attributes)}}
  end

  def program_payload(name, source_digest:, attributes: [POSITION_ATTRIBUTE])
    manifest = manifest_json(name, attributes: attributes).fetch("programs").fetch(name)
    {
      "name" => name, "source_digest" => source_digest, "vertex" => "v", "fragment" => "f",
      "manifest" => {"schema_version" => 1, "generated_at" => "1970-01-01T00:00:00Z", "programs" => {name => manifest}},
      "source_maps" => {"vertex" => {"version" => 1, "files" => [], "segments" => []},
                        "fragment" => {"version" => 1, "files" => [], "segments" => []}},
      "diagnostics" => []
    }
  end

  def stub_fetch(routes)
    JS.global.fetch_handler = lambda { |url|
      body = routes.fetch(url) { raise "no stub for #{url.inspect}" }
      JS::FakePromise.resolved(JS::FakeResponse.new(ok: true, body: JSON.generate(body)))
    }
  end

  def build_context(gl)
    context = Glslkit::WebGL::Context.new(gl, fake_canvas)
    context.program(manifest_json("neon"), "neon", vertex: "v", fragment: "f")
    context
  end

  def test_reload_is_triggered_when_the_digest_changes
    gl = FakeGL.new
    context = build_context(gl)

    reloaded = false
    stub_fetch(
      "/glslkit/digests.json" => {"neon" => "digest-1"},
      "/glslkit/programs/neon.json" => program_payload("neon", source_digest: "digest-1")
    )
    context.live_reload("neon", on_error: ->(e) { flunk("unexpected on_error: #{e}") }, on_reload: ->(_r) { reloaded = true })

    JS.global.tick_interval

    assert reloaded
  end

  def test_program_body_is_not_fetched_again_when_the_digest_is_unchanged
    gl = FakeGL.new
    context = build_context(gl)

    program_fetch_count = 0
    JS.global.fetch_handler = lambda { |url|
      program_fetch_count += 1 if url == "/glslkit/programs/neon.json"
      body = case url
      when "/glslkit/digests.json" then {"neon" => "digest-1"}
      when "/glslkit/programs/neon.json" then program_payload("neon", source_digest: "digest-1")
      else raise "no stub for #{url.inspect}"
      end
      JS::FakePromise.resolved(JS::FakeResponse.new(ok: true, body: JSON.generate(body)))
    }
    context.live_reload("neon", on_error: ->(e) { flunk("unexpected on_error: #{e}") })

    JS.global.tick_interval
    JS.global.tick_interval

    assert_equal 1, program_fetch_count
  end

  def test_polling_continues_after_a_reload_failure
    gl = FakeGL.new
    context = build_context(gl)

    errors = []
    reloaded = []
    context.live_reload("neon", on_error: ->(e) { errors << e }, on_reload: ->(r) { reloaded << r })

    # 1回目: コンパイル失敗させ、reload_programがCompileErrorを投げる状況を作る。
    stub_fetch(
      "/glslkit/digests.json" => {"neon" => "digest-broken"},
      "/glslkit/programs/neon.json" => program_payload("neon", source_digest: "digest-broken")
    )
    gl.shader_ok = false
    gl.shader_log = "ERROR: 0:1: broken"
    JS.global.tick_interval

    assert_equal 1, errors.length
    assert_kind_of Glslkit::WebGL::CompileError, errors.first
    assert_empty reloaded

    # ポーリング自体(setInterval)が生きていることを、2回目のtickが実際に
    # 新しいdigestを検知して成功することで示す。
    gl.shader_ok = true
    stub_fetch(
      "/glslkit/digests.json" => {"neon" => "digest-fixed"},
      "/glslkit/programs/neon.json" => program_payload("neon", source_digest: "digest-fixed")
    )
    JS.global.tick_interval

    assert_equal 1, reloaded.length
  end

  def test_a_single_setinterval_is_shared_across_multiple_watched_programs
    gl = FakeGL.new
    context = Glslkit::WebGL::Context.new(gl, fake_canvas)
    context.program(manifest_json("a"), "a", vertex: "v", fragment: "f")
    context.program(manifest_json("b"), "b", vertex: "v", fragment: "f")

    context.live_reload("a")
    assert_equal 1, JS.global.interval_count

    context.live_reload("b")
    assert_equal 1, JS.global.interval_count
  end
end
