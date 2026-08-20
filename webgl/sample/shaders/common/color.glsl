#pragma once

vec3 palette(float t) {
  return 0.55 + 0.45 * cos(6.28318 * (vec3(0.02, 0.18, 0.38) * t + vec3(0.0, 0.18, 0.42)));
}
