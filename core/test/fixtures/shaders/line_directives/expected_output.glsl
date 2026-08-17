#version 300 es
#line 2 0
precision mediump float;
#line 1 1
// lib
float foo() { return 1.0; }
#line 4 0
void main() {
  gl_FragColor = vec4(1.0);
}
