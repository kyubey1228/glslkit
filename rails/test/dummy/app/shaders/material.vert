#version 300 es
#include "common/camera.glsl"

layout(location = 0) in vec3 a_position;
layout(location = 1) in vec3 a_normal;
layout(location = 2) in vec2 a_uv;

uniform mat4 u_model;

out vec3 v_world_position;
out vec3 v_normal;
out vec2 v_uv;

void main() {
  vec4 world_position = u_model * vec4(a_position, 1.0);
  v_world_position = world_position.xyz;
  v_normal = mat3(u_model) * a_normal;
  v_uv = a_uv;
  gl_Position = projection * view * world_position;
}
