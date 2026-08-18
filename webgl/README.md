# glslkit-webgl

`glslkit-webgl` is a WebGL2 runtime for Ruby programs running in a browser with
ruby.wasm. It consumes a `glslkit` reflection manifest, caches WebGL references,
and reports shader compiler errors as Ruby exceptions.

## Quick start

Serve this repository over HTTP and open `webgl/sample/index.html`. The sample
draws a rotating, textured cube without application JavaScript.
`webgl/sample/compile-error.html` demonstrates original-file error mapping.

```html
<canvas id="canvas" width="640" height="480"></canvas>
<script src="/path/to/glslkit-webgl.js" data-entry="./app.rb"
        data-ruby-version="4.0" data-wasm-wasi-version="2.10.1"></script>
```

The shim only starts ruby.wasm. `JS::RequireRemote` fetches Ruby files and all
rendering logic remains in Ruby. `window.glslkitWebGLReady` settles when the entry
file finishes loading. Packaged wasm builds should install both gems normally.

## Runtime API

```ruby
require "glslkit/webgl"

ctx = Glslkit::WebGL.context("#canvas")
manifest = Glslkit::Manifest.parse(MANIFEST_JSON)
program = ctx.program(manifest, "main", vertex: VERTEX_SOURCE,
  fragment: FRAGMENT_SOURCE,
  source_maps: {vertex: vertex_map, fragment: fragment_map})
geometry = ctx.geometry(program: program, attributes: {
  a_position: {data: positions, components: 3},
  a_uv: {data: uvs, components: 2}
}, indices: indices)
texture = ctx.texture2d(width: 2, height: 2, data: rgba_pixels, unit: 0)

matrix = JS.global[:Float32Array].new(16)
ctx.loop do |seconds|
  Glslkit::WebGL::Matrix.rotation_z!(matrix, seconds)
  program.set(:u_transform, matrix)
  program.set(:u_texture, texture.unit)
  texture.bind
  ctx.draw(geometry, program: program)
end
```

Unknown uniforms and incorrect `element_count` values raise immediately.
Locations optimized away by GLSL are silently ignored. Geometry data is uploaded
once with typed-array `from`; there is intentionally no mutation API.

## Shader errors and source maps

Pass each stage's `Glslkit::SourceMap` through `source_maps:`. Recognized driver
line numbers are resolved to the original included file. `CompileError` exposes
`stage`, `file`, `line`, and `raw_log`. Unknown log formats still raise, with
`file` and `line` set to `nil`. Link failures raise `LinkError`. JS log values are
converted with `#to_s` before parsing.

## Debug mode

Set `Glslkit::WebGL.debug = true` to call `getError` once at each frame end. It
defaults to `false` and should not remain enabled because `getError` synchronizes
the WebGL command queue.

## Performance and scope limits

The following CPU-side workloads are unsupported in v0.1:

- replacing vertex data every frame;
- CPU skinning;
- CPU morph-target interpolation;
- CPU-updated particle geometry.

Transferring 100,000 floats took 18.8 ms in the design measurements, exceeding a
60 fps frame budget. Keep geometry static, deform vertices in shaders, and send
only matrices and weights through uniforms. Per-frame bone-matrix calculation
cost remains unmeasured.

The runtime is WebGL2-only. It has no WebGL1 fallback, scene graph, material
system, or glTF/VRM loader.

## JS value safety (R6)

Never call `#class` on a value that may be a `JS::Object`; JavaScript primitives
can fail in `Reflect.has`. Use `is_a?(JS::Object)` for checks and `#inspect`,
`#typeof`, or `#to_s` for display. A test scans implementation Ruby files for
accidental `.class` calls.

Normal CRuby fails immediately with a clear message because ruby.wasm's `js`
library is required.
