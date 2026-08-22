# frozen_string_literal: true

require_relative "../lib/glslkit/webgl"
require_relative "generated/cube_shaders"

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
program = ctx.program(Glslkit::Manifest.parse(CubeShaders::MANIFEST), "cube",
  vertex: CubeShaders::VERTEX, fragment: CubeShaders::FRAGMENT,
  source_maps: {
    vertex: Glslkit::SourceMap.from_h(CubeShaders::SOURCE_MAPS[:vertex]),
    fragment: Glslkit::SourceMap.from_h(CubeShaders::SOURCE_MAPS[:fragment])
  })
geometry = ctx.geometry(program: program, attributes: {
  a_position: {data: POSITIONS, components: 3}, a_uv: {data: UVS, components: 2}
}, indices: INDICES)
texture = ctx.texture2d(width: 2, height: 2, data: PIXELS, unit: 0)

projection = Array.new(16, 0.0)
view = Array.new(16, 0.0)
model = Array.new(16, 0.0)
view_model = Array.new(16, 0.0)
mvp = Array.new(16, 0.0)
Glslkit::WebGL::Matrix.perspective!(projection, Math::PI / 3.0, 1.0, 0.1, 100.0)
Glslkit::WebGL::Matrix.translation!(view, 0.0, 0.0, -4.0)

ctx.viewport
ctx.depth_test = true
program.set(:u_texture, texture.unit)
ctx.loop do |seconds|
  Glslkit::WebGL::Matrix.rotation_y!(model, seconds)
  Glslkit::WebGL::Matrix.multiply!(view_model, view, model)
  Glslkit::WebGL::Matrix.multiply!(mvp, projection, view_model)
  program.set(:u_mvp, mvp)
  texture.bind
  ctx.clear(red: 0.04, green: 0.05, blue: 0.09)
  ctx.draw(geometry)
end
