# glslkit-webgl

WebGL2 bindings for Ruby applications running in a browser with ruby.wasm.

The bundled shim boots ruby.wasm and loads the Ruby entry file through
`JS::RequireRemote`. Normal CRuby fails immediately with a clear message because
the ruby.wasm `js` library is required.

Do not call `#class` on values that may be `JS::Object` instances. Use
`is_a?(JS::Object)`, `#inspect`, `#typeof`, or `#to_s` instead.
