# glslkit-rails

[`glslkit`](../core) を Rails (Propshaft) のアセットパイプラインに統合する gem。
`.glsl` / `.vert` / `.frag` をアセットとして登録し、`#include` を解決した内容を
配信し、`assets:precompile` 時にリフレクションマニフェストを書き出す。

## インストール

```ruby
gem "glslkit-rails"
```

`glslkit`・`railties >= 7.1`・`propshaft >= 1.3.2` に依存する。

## 設定

```ruby
# config/application.rb
config.glslkit.paths = ["app/shaders"]          # デフォルト: app/shaders
config.glslkit.minify = Rails.env.production?
config.glslkit.line_directives = !Rails.env.production?
config.glslkit.manifest_path = "glsl-manifest.json"
```

## アセットとしての配信

`config.glslkit.paths` 配下のファイルはPropshaftのload_pathに追加され、
`#include` を解決した内容がcontent_type `x-shader/x-vertex` /
`x-shader/x-fragment` / `text/plain` で配信される。developmentでは
毎リクエスト再処理し、productionでは `assets:precompile` 時に1回だけ処理する。

## マニフェスト

`rake assets:precompile` を実行すると、自動的に
`public/assets/<config.glslkit.manifest_path>` (デフォルト `glsl-manifest.json`)
にリフレクションマニフェストを書き出す。単体で実行する場合:

```
rake glslkit:reflect
```

Ruby側から読む場合:

```ruby
Glslkit::Rails.manifest # => Hash (productionでは読み込み結果をメモ化する)
```

## ビューヘルパー

```erb
<%= glsl_script_tag "pbr.vert" %>
<%# => <script type="x-shader/x-vertex" id="pbr-vert">...</script> （インライン埋め込み） %>

<%= glsl_manifest_tag %>
<%# => <script type="application/json" id="glsl-manifest">...</script> %>
```

- インライン埋め込みの内容は `</script` をエスケープしている
- CSPを `config.content_security_policy_nonce_auto = true` で有効にしている場合、
  Railsの `javascript_tag` と同じ規約で自動的に `nonce` 属性を付与する
  (`nonce: false` で明示的に抑止することもできる)

## 実践的な例

`app/shaders/` にPBR風のマテリアルシェーダーを置く。共有partialの
uniform block、複数テクスチャ、uniform配列を含む、より現実的な構成:

```glsl
# app/shaders/common/camera.glsl
layout(std140, binding = 0) uniform Camera {
  mat4 view;
  mat4 projection;
  vec3 eye_position;
};
```

```glsl
# app/shaders/material.vert
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
```

```glsl
# app/shaders/material.frag
#version 300 es
precision highp float;
#include "common/camera.glsl"

in vec3 v_world_position;
in vec3 v_normal;
in vec2 v_uv;

uniform sampler2D u_albedo_map;
uniform vec4 u_base_color;
uniform vec3 u_light_positions[4];
uniform vec3 u_light_colors[4];
uniform int u_light_count;

out vec4 fragColor;

void main() {
  vec3 albedo = texture(u_albedo_map, v_uv).rgb * u_base_color.rgb;
  vec3 n = normalize(v_normal);

  vec3 total = vec3(0.0);
  for (int i = 0; i < u_light_count; i++) {
    vec3 to_light = normalize(u_light_positions[i] - v_world_position);
    total += albedo * u_light_colors[i] * max(dot(n, to_light), 0.0);
  }

  fragColor = vec4(total, u_base_color.a);
}
```

ビューでは平坦化済みシェーダーとマニフェストをまとめて埋め込む:

```erb
<%# app/views/scenes/show.html.erb %>
<%= glsl_script_tag "material.vert" %>
<%= glsl_script_tag "material.frag" %>
<%= glsl_manifest_tag %>
```

`glsl_script_tag "material.vert"` は `#include "common/camera.glsl"` を
解決した平坦化済みGLSLを `id="material-vert"` として埋め込み、
`glsl_manifest_tag` は attribute の location・uniform の型/setter/配列サイズ・
uniform blockのlayout/bindingを持つJSONを `id="glsl-manifest"` として埋め込む。

JS側は、このマニフェストを消費するだけでWebGLプログラムをセットアップできる。
**`gl.getActiveUniform`/`gl.getActiveAttrib` でイントロスペクションするループが
不要になる**のがglslkitの狙い:

```js
function compileProgram(gl, manifestProgram, shaderElementIds) {
  const vertexShader = compileShader(gl, gl.VERTEX_SHADER,
    document.getElementById(shaderElementIds.vertex).textContent);
  const fragmentShader = compileShader(gl, gl.FRAGMENT_SHADER,
    document.getElementById(shaderElementIds.fragment).textContent);

  const program = gl.createProgram();
  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragmentShader);
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    throw new Error(gl.getProgramInfoLog(program));
  }

  const attributes = {};
  for (const attr of manifestProgram.attributes) {
    // location: null の場合だけ getAttribLocation を引けばよい
    attributes[attr.name] = attr.location ?? gl.getAttribLocation(program, attr.name);
  }

  const uniforms = {};
  let textureUnit = 0;
  for (const uniform of manifestProgram.uniforms) {
    const location = gl.getUniformLocation(program, uniform.name);
    if (!location) continue; // 未使用uniformはコンパイラに削除されうる

    if (uniform.sampler) {
      const unit = textureUnit++;
      uniforms[uniform.name] = (texture) => {
        gl.activeTexture(gl.TEXTURE0 + unit);
        gl.bindTexture(gl.TEXTURE_2D, texture);
        gl.uniform1i(location, unit);
      };
    } else if (uniform.matrix) {
      uniforms[uniform.name] = (value) => gl[uniform.setter](location, false, value);
    } else {
      uniforms[uniform.name] = (value) => gl[uniform.setter](location, value);
    }
  }

  return {program, attributes, uniforms};
}

function compileShader(gl, type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    throw new Error(gl.getShaderInfoLog(shader));
  }
  return shader;
}

const manifest = JSON.parse(document.getElementById("glsl-manifest").textContent);
const material = compileProgram(gl, manifest.programs.material, {
  vertex: "material-vert",
  fragment: "material-frag",
});

material.uniforms.u_model(modelMatrix);
material.uniforms.u_base_color(new Float32Array([1, 1, 1, 1]));
material.uniforms.u_albedo_map(albedoTexture);
```

`uniform.setter`/`uniform.matrix`/`uniform.sampler`はすべて
[`Glslkit::Types`](../core#マニフェスト生成)由来で、`spec/schema/reflection-v1.json`
に準拠する。

## ライセンス

[MIT](LICENSE.txt)
