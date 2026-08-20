# frozen_string_literal: true

require_relative "../lib/glslkit/webgl"

VERTEX_SOURCE = <<~GLSL
  #version 300 es
  layout(location = 0) in vec3 a_position;
  layout(location = 1) in vec2 a_uv;
  uniform mat4 u_mvp;
  out vec2 v_uv;
  void main() {
    v_uv = a_uv;
    gl_Position = u_mvp * vec4(a_position, 1.0);
  }
GLSL

FRAGMENT_SOURCE = <<~GLSL
  #version 300 es
  precision mediump float;
  in vec2 v_uv;
  uniform sampler2D u_texture;
  out vec4 frag_color;
  void main() {
    frag_color = texture(u_texture, v_uv);
  }
GLSL

MANIFEST = {
  "schema_version" => 1, "generated_at" => "2026-08-18T00:00:00Z",
  "programs" => {"cube" => {
    "digest" => "0" * 64,
    "stages" => {
      "vertex" => {"path" => "cube.vert", "digest" => "0" * 64, "url" => ""},
      "fragment" => {"path" => "cube.frag", "digest" => "0" * 64, "url" => ""}
    },
    "attributes" => [
      {"name" => "a_position", "type" => "vec3", "location" => 0, "array_size" => 1},
      {"name" => "a_uv", "type" => "vec2", "location" => 1, "array_size" => 1}
    ],
    "uniforms" => [
      {"name" => "u_mvp", "type" => "mat4", "array_size" => 1,
       "setter" => "uniformMatrix4fv", "matrix" => true, "sampler" => false,
       "components" => 16, "element_count" => 16, "stages" => ["vertex"]},
      {"name" => "u_texture", "type" => "sampler2D", "array_size" => 1,
       "setter" => "uniform1iv", "matrix" => false, "sampler" => true,
       "components" => 1, "element_count" => 1, "stages" => ["fragment"]}
    ],
    "uniform_blocks" => [],
    "outputs" => [{"name" => "frag_color", "type" => "vec4", "location" => nil}]
  }}
}.freeze

POSITIONS = [
  -1, -1, -1, 1, -1, -1, 1, 1, -1, -1, 1, -1,
  -1, -1, 1, 1, -1, 1, 1, 1, 1, -1, 1, 1
].freeze
UVS = [0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1].freeze
INDICES = [
  0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6,
  0, 4, 5, 0, 5, 1, 3, 2, 6, 3, 6, 7,
  1, 5, 6, 1, 6, 2, 0, 3, 7, 0, 7, 4
].freeze
PIXELS = [
  255, 80, 120, 255, 40, 210, 255, 255,
  40, 210, 255, 255, 255, 80, 120, 255
].freeze

ctx = Glslkit::WebGL.context("#canvas")
program = ctx.program(Glslkit::Manifest.parse(MANIFEST), "cube",
  vertex: VERTEX_SOURCE, fragment: FRAGMENT_SOURCE)
geometry = ctx.geometry(program: program, attributes: {
  a_position: {data: POSITIONS, components: 3}, a_uv: {data: UVS, components: 2}
}, indices: INDICES)
texture = ctx.texture2d(width: 2, height: 2, data: PIXELS, unit: 0)

projection = JS.global[:Float32Array].new(16)
view = JS.global[:Float32Array].new(16)
model = JS.global[:Float32Array].new(16)
view_model = JS.global[:Float32Array].new(16)
mvp = JS.global[:Float32Array].new(16)
Glslkit::WebGL::Matrix.perspective!(projection, Math::PI / 3.0, 1.0, 0.1, 100.0)
Glslkit::WebGL::Matrix.translation!(view, 0.0, 0.0, -4.0)

ctx.viewport(640, 640)
ctx.depth_test = true
program.set(:u_texture, texture.unit)
ctx.loop do |seconds|
  Glslkit::WebGL::Matrix.rotation_y!(model, seconds)
  Glslkit::WebGL::Matrix.multiply!(view_model, view, model)
  Glslkit::WebGL::Matrix.multiply!(mvp, projection, view_model)
  program.set(:u_mvp, mvp)
  texture.bind
  ctx.clear(red: 0.04, green: 0.05, blue: 0.09)
  ctx.draw(geometry, program: program)
end
