# frozen_string_literal: true

# 自動生成 (rake glslkit:embed)。手で編集しない。
# 再生成するには: bundle exec rake glslkit:embed[shaders_dir,out_dir]
#
# MANIFESTのgenerated_atが1970-01-01なのはバグではない。生成の
# 冪等性(同じ入力から同じ出力になること)のための固定値であり、
# 実行時刻を使うと同じ入力でも実行のたびにgit diffが出てしまう。
# 再現性はstages.*.digest(実データから計算される)が担保している。

module NeonShaders
  VERTEX = <<'GLSLKIT_VERTEX_SRC'.freeze
#version 300 es
layout(location = 0) in vec2 a_position;
void main() {
  gl_Position = vec4(a_position, 0.0, 1.0);
}
GLSLKIT_VERTEX_SRC

  FRAGMENT = <<'GLSLKIT_FRAGMENT_SRC'.freeze
#version 300 es
precision highp float;

uniform float u_time;
uniform vec2 u_resolution;
out vec4 frag_color;

#define PI 3.14159265359


mat2 rotate2d(float angle) {
  float c = cos(angle), s = sin(angle);
  return mat2(c, -s, s, c);
}

float sdTorus(vec3 p, vec2 t) {
  vec2 q = vec2(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}

vec3 palette(float t) {
  return 0.55 + 0.45 * cos(6.28318 * (vec3(0.02, 0.18, 0.38) * t + vec3(0.0, 0.18, 0.42)));
}

float scene(vec3 p) {
  p.xz *= rotate2d(u_time * 0.32);
  p.xy *= rotate2d(sin(u_time * 0.27) * 0.55);

  float angle = atan(p.z, p.x);
  float pulse = 0.10 * sin(angle * 7.0 + u_time * 2.4);
  float portal = sdTorus(p, vec2(1.25, 0.17 + pulse));

  vec3 orb = p;
  orb.xz *= rotate2d(-u_time * 0.7);
  orb -= vec3(1.25, sin(u_time * 1.8) * 0.22, 0.0);
  float satellite = length(orb) - 0.11;
  return min(portal, satellite);
}

vec3 normalAt(vec3 p) {
  vec2 e = vec2(0.0015, 0.0);
  float d = scene(p);
  return normalize(vec3(
    scene(p + e.xyy) - d,
    scene(p + e.yxy) - d,
    scene(p + e.yyx) - d
  ));
}

float raymarch(vec3 origin, vec3 direction, out vec3 point) {
  float distanceTravelled = 0.0;
  for (int i = 0; i < 96; i++) {
    point = origin + direction * distanceTravelled;
    float distanceToScene = scene(point);
    if (distanceToScene < 0.001 || distanceTravelled > 12.0) break;
    distanceTravelled += distanceToScene * 0.72;
  }
  return distanceTravelled;
}

void main() {
  vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution) / u_resolution.y;
  float vignette = max(0.0, 1.0 - dot(uv, uv) * 0.28);

  vec3 origin = vec3(0.0, 0.0, 4.2);
  vec3 direction = normalize(vec3(uv, -1.8));
  vec3 point;
  float travelled = raymarch(origin, direction, point);

  vec3 color = vec3(0.006, 0.008, 0.025);
  float rays = pow(max(0.0, 1.0 - length(uv)), 5.0);
  color += vec3(0.12, 0.03, 0.30) * rays;

  if (travelled < 12.0) {
    vec3 normal = normalAt(point);
    vec3 light = normalize(vec3(0.7, 1.2, 2.0));
    float diffuse = max(dot(normal, light), 0.0);
    float rim = pow(1.0 - max(dot(normal, -direction), 0.0), 2.4);
    float bands = 0.5 + 0.5 * sin(atan(point.z, point.x) * 9.0 - u_time * 3.0);
    vec3 neon = palette(bands + u_time * 0.06);
    color += neon * (0.18 + diffuse * 0.65 + rim * 2.4);
    color += pow(max(dot(reflect(-light, normal), -direction), 0.0), 32.0);
  }

  float glowDistance = abs(length(uv) - 0.47 - sin(atan(uv.y, uv.x) * 7.0 + u_time) * 0.018);
  color += palette(u_time * 0.07 + length(uv)) * 0.012 / max(glowDistance, 0.008);

  color *= vignette;
  color = pow(color, vec3(0.82));
  frag_color = vec4(color, 1.0);
}
GLSLKIT_FRAGMENT_SRC

  MANIFEST = {"schema_version"=>1,
 "generated_at"=>"1970-01-01T00:00:00Z",
 "programs"=>
  {"neon"=>
    {"digest"=>
      "b7fb9408aaff4ba38dd6a9be7429fb99962e9878a085e5e034bf1d9f8b3ea5a7",
     "stages"=>
      {"vertex"=>
        {"path"=>"neon.vert",
         "digest"=>
          "9cf045b60aee6e157a1b7b83b2ce299dd479f8d2d16d2418914db2fedeb37627",
         "url"=>"neon.vert"},
       "fragment"=>
        {"path"=>"neon.frag",
         "digest"=>
          "71c73491886569fc5546df1510755b3023a784aec25b635f31cdcc76facece27",
         "url"=>"neon.frag"}},
     "attributes"=>
      [{"name"=>"a_position", "type"=>"vec2", "location"=>0, "array_size"=>1}],
     "uniforms"=>
      [{"name"=>"u_time",
        "type"=>"float",
        "array_size"=>1,
        "setter"=>"uniform1fv",
        "matrix"=>false,
        "sampler"=>false,
        "components"=>1,
        "element_count"=>1,
        "stages"=>["fragment"]},
       {"name"=>"u_resolution",
        "type"=>"vec2",
        "array_size"=>1,
        "setter"=>"uniform2fv",
        "matrix"=>false,
        "sampler"=>false,
        "components"=>2,
        "element_count"=>2,
        "stages"=>["fragment"]}],
     "uniform_blocks"=>[],
     "outputs"=>[{"name"=>"frag_color", "type"=>"vec4", "location"=>nil}]}}}.freeze

  SOURCE_MAPS = {
    vertex: {"version"=>1, "files"=>["neon.vert"], "segments"=>[[2, 0, 2]]},
    fragment: {"version"=>1,
 "files"=>["neon.frag", "common/sdf.glsl", "common/color.glsl"],
 "segments"=>[[2, 0, 2], [10, 1, 2], [20, 2, 2], [24, 0, 12]]}
  }.freeze
end
