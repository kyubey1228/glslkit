#version 300 es
precision mediump float;
#include "common/math.glsl"
uniform sampler2D u_albedo;
out vec4 fragColor;
void main() {
  fragColor = texture(u_albedo, vec2(pi(), 0.0));
}
