#version 300 es
precision highp float;
#include "common/camera.glsl"

#define MAX_LIGHTS 4

in vec3 v_world_position;
in vec3 v_normal;
in vec2 v_uv;

uniform sampler2D u_albedo_map;
uniform sampler2D u_normal_map;
uniform sampler2D u_metallic_roughness_map;
uniform vec4 u_base_color;
uniform float u_metallic;
uniform float u_roughness;
uniform vec3 u_light_positions[4]; // glslkitは#defineを評価しないため配列サイズは常にリテラルで書く
uniform vec3 u_light_colors[4];
uniform int u_light_count;

out vec4 fragColor;

void main() {
  vec3 albedo = texture(u_albedo_map, v_uv).rgb * u_base_color.rgb;
  vec3 n = normalize(v_normal);

  vec3 total = vec3(0.0);
  for (int i = 0; i < u_light_count; i++) {
    vec3 to_light = normalize(u_light_positions[i] - v_world_position);
    float ndotl = max(dot(n, to_light), 0.0);
    total += albedo * u_light_colors[i] * ndotl;
  }

  fragColor = vec4(total, u_base_color.a);
}
