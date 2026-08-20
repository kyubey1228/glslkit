# frozen_string_literal: true

require_relative "../lib/glslkit/webgl"
require_relative "generated/neon_shaders"

ctx = Glslkit::WebGL.context("#canvas")
program = ctx.program(Glslkit::Manifest.parse(NeonShaders::MANIFEST), "neon",
  vertex: NeonShaders::VERTEX, fragment: NeonShaders::FRAGMENT,
  source_maps: {
    vertex: Glslkit::SourceMap.from_h(NeonShaders::SOURCE_MAPS[:vertex]),
    fragment: Glslkit::SourceMap.from_h(NeonShaders::SOURCE_MAPS[:fragment])
  })
screen = ctx.geometry(program: program, attributes: {
  a_position: {data: [-1.0, -1.0, 3.0, -1.0, -1.0, 3.0], components: 2}
})

ctx.viewport
program.set(:u_resolution, [ctx.width.to_f, ctx.height.to_f])
ctx.loop do |seconds|
  program.set(:u_time, seconds)
  ctx.draw(screen)
end
