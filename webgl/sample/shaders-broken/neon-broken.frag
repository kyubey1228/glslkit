#version 300 es
precision highp float;

uniform float u_time;
uniform vec2 u_resolution;
out vec4 frag_color;

#define PI 3.14159265359

#include "common/sdf.glsl"
#include "common/color.glsl"

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
