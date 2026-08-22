# frozen_string_literal: true

# 自動生成 (rake glslkit:embed)。手で編集しない。
# 再生成するには: bundle exec rake glslkit:embed[shaders_dir,out_dir]
#
# MANIFESTのgenerated_atが1970-01-01なのはバグではない。生成の
# 冪等性(同じ入力から同じ出力になること)のための固定値であり、
# 実行時刻を使うと同じ入力でも実行のたびにgit diffが出てしまう。
# 再現性はstages.*.digest(実データから計算される)が担保している。

module CubeShaders
  VERTEX = <<'GLSLKIT_VERTEX_SRC'.freeze
#version 300 es
layout(location = 0) in vec3 a_position;
layout(location = 1) in vec2 a_uv;
uniform mat4 u_mvp;
out vec2 v_uv;
void main() {
  v_uv = a_uv;
  gl_Position = u_mvp * vec4(a_position, 1.0);
}
GLSLKIT_VERTEX_SRC

  FRAGMENT = <<'GLSLKIT_FRAGMENT_SRC'.freeze
#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D u_texture;
out vec4 frag_color;
void main() {
  frag_color = texture(u_texture, v_uv);
}
GLSLKIT_FRAGMENT_SRC

  MANIFEST = {"schema_version"=>1,
 "generated_at"=>"1970-01-01T00:00:00Z",
 "generator"=>"glslkit/0.1.0",
 "programs"=>
  {"cube"=>
    {"digest"=>
      "a3743db5891346c02adf840ae7246c1b7e911c4511eab0290dcc81a7e80eb08a",
     "stages"=>
      {"vertex"=>
        {"path"=>"cube.vert",
         "digest"=>
          "8f1de9ac637f6872e2563399c33af571bc74741e651726eb2ece6e69c03ce433",
         "url"=>"cube.vert"},
       "fragment"=>
        {"path"=>"cube.frag",
         "digest"=>
          "92a077871371847d2a1cd568bc082d5bc2e840293e1c0cecb0ae39559e114dc1",
         "url"=>"cube.frag"}},
     "attributes"=>
      [{"name"=>"a_position", "type"=>"vec3", "location"=>0, "array_size"=>1},
       {"name"=>"a_uv", "type"=>"vec2", "location"=>1, "array_size"=>1}],
     "uniforms"=>
      [{"name"=>"u_mvp",
        "type"=>"mat4",
        "array_size"=>1,
        "setter"=>"uniformMatrix4fv",
        "matrix"=>true,
        "sampler"=>false,
        "components"=>16,
        "element_count"=>16,
        "stages"=>["vertex"]},
       {"name"=>"u_texture",
        "type"=>"sampler2D",
        "array_size"=>1,
        "setter"=>"uniform1iv",
        "matrix"=>false,
        "sampler"=>true,
        "components"=>1,
        "element_count"=>1,
        "stages"=>["fragment"]}],
     "uniform_blocks"=>[],
     "outputs"=>[{"name"=>"frag_color", "type"=>"vec4", "location"=>nil}]}}}.freeze

  SOURCE_MAPS = {
    vertex: {"version"=>1, "files"=>["cube.vert"], "segments"=>[[2, 0, 2]]},
    fragment: {"version"=>1, "files"=>["cube.frag"], "segments"=>[[2, 0, 2]]}
  }.freeze
end
