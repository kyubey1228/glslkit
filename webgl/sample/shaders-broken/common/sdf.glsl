#pragma once

mat2 rotate2d(float angle) {
  float c = cos(angle), s = sin(angle)
  return mat2(c, -s, s, c);
}

float sdTorus(vec3 p, vec2 t) {
  vec2 q = vec2(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}
