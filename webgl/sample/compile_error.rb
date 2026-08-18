# frozen_string_literal: true

require_relative "../lib/glslkit/webgl"

vertex = <<~GLSL
  #version 300 es
  void main() { gl_Position = vec4(0.0); }
GLSL
fragment = <<~GLSL
  #version 300 es
  precision mediump float;
  out vec4 frag_color;
  void main() {
    frag_color = vec4(1.0)
  }
GLSL
manifest = {
  "schema_version" => 1, "generated_at" => "2026-08-18T00:00:00Z",
  "programs" => {"broken" => {
    "digest" => "0" * 64, "stages" => {}, "attributes" => [], "uniforms" => [],
    "uniform_blocks" => [], "outputs" => []
  }}
}
source_map = Glslkit::SourceMap.new
file_index = source_map.index_for("common/broken-color.glsl")
source_map.add_segment(output_line: 1, file_index: file_index, source_line: 20)

result = JS.global[:document].call(:getElementById, "result")
begin
  Glslkit::WebGL.context("#canvas").program(
    Glslkit::Manifest.parse(manifest), "broken", vertex: vertex, fragment: fragment,
    source_maps: {fragment: source_map}
  )
  result[:textContent] = "unexpected success"
rescue Glslkit::WebGL::CompileError => error
  result[:textContent] = [error.stage, error.file, error.line, error.message].join("|")
end
