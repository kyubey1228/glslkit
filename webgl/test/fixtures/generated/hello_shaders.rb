# frozen_string_literal: true

# 自動生成 (rake glslkit:embed)。手で編集しない。
# 再生成するには: bundle exec rake glslkit:embed[shaders_dir,out_dir]

module HelloShaders
  VERTEX = <<'GLSLKIT_VERTEX_SRC'.freeze
#version 300 es
layout(location = 0) in vec2 a_position;
uniform mat4 u_transform;
void main() {
  gl_Position = u_transform * vec4(a_position, 0.0, 1.0);
}
GLSLKIT_VERTEX_SRC

  FRAGMENT = <<'GLSLKIT_FRAGMENT_SRC'.freeze
#version 300 es
precision highp float;

vec4 tint(float t) {
  return vec4(0.5 + 0.5 * sin(t), 0.5, 0.5, 1.0);
}

uniform float u_time;
out vec4 frag_color;

void main() {
  frag_color = tint(u_time);
}
GLSLKIT_FRAGMENT_SRC

  MANIFEST = {"schema_version"=>1,
 "generated_at"=>"1970-01-01T00:00:00Z",
 "programs"=>
  {"hello"=>
    {"digest"=>
      "4e15d92105b1362c0ebf2522dd58d4f384ee93af16a84267279cd5215eaf8f06",
     "stages"=>
      {"vertex"=>
        {"path"=>"hello.vert",
         "digest"=>
          "0daf0fa4cb3fadb341ecdb326920277eaed7ea9227fe90a82165e7ae2d785604",
         "url"=>"hello.vert"},
       "fragment"=>
        {"path"=>"hello.frag",
         "digest"=>
          "36de847a58e55179a087aa984f1339b5181ac0cc50c8a287db6b7406bc3e419b",
         "url"=>"hello.frag"}},
     "attributes"=>
      [{"name"=>"a_position", "type"=>"vec2", "location"=>0, "array_size"=>1}],
     "uniforms"=>
      [{"name"=>"u_transform",
        "type"=>"mat4",
        "array_size"=>1,
        "setter"=>"uniformMatrix4fv",
        "matrix"=>true,
        "sampler"=>false,
        "components"=>16,
        "element_count"=>16,
        "stages"=>["vertex"]},
       {"name"=>"u_time",
        "type"=>"float",
        "array_size"=>1,
        "setter"=>"uniform1fv",
        "matrix"=>false,
        "sampler"=>false,
        "components"=>1,
        "element_count"=>1,
        "stages"=>["fragment"]}],
     "uniform_blocks"=>[],
     "outputs"=>[{"name"=>"frag_color", "type"=>"vec4", "location"=>nil}]}}}.freeze

  SOURCE_MAPS = {
    vertex: {"version"=>1, "files"=>["hello.vert"], "segments"=>[[2, 0, 2]]},
    fragment: {"version"=>1,
 "files"=>["hello.frag", "common/tint.glsl"],
 "segments"=>[[2, 0, 2], [3, 1, 2], [7, 0, 4]]}
  }.freeze
end
