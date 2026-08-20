#version 300 es
precision highp float;
#include "common/tint.glsl"

uniform float u_time;
out vec4 frag_color;

void main() {
  frag_color = tint(u_time);
}
