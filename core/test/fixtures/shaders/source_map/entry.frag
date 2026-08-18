#version 300 es
precision mediump float;
#include "common/math.glsl"
uniform sampler2D u_albedo;
out vec4 fragColor;
void main() {
  fragColor = vec4(helper() * u_scale, 0.0, 0.0, 1.0);
}
