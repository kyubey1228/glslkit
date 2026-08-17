# glslkit

GLSLソースを前処理・解析し、ビルド時に得たリフレクション情報（uniform / attribute
/ output / uniform block）をJSONとして残すためのRuby gem。実行時依存はゼロ
（stdlibの `json` `strscan` `set` `digest` のみ）で、将来 [ruby.wasm](https://github.com/ruby/ruby.wasm)
上のWebGLバインディングにそのまま組み込めることを狙っている。

Rails (Propshaft) との統合は別gem [`glslkit-rails`](../rails) が提供する。

## インストール

```ruby
gem "glslkit"
```

## 使い方

```ruby
require "glslkit"

resolver = Glslkit::Resolvers::FileSystem.new(load_paths: ["app/shaders"])
source   = Glslkit::Preprocessor.new(resolver: resolver).process("pbr.frag")

source.code        # => 平坦化済みGLSL (String)。#include解決済み、#lineディレクティブ付き
source.reflection  # => Glslkit::Reflection (attributes / uniforms / uniform_blocks / outputs)
source.source_map  # => Glslkit::SourceMap (#lineのファイルインデックス → パス)
source.digest      # => SHA256 hex (String)
```

### `#include` の解決

```glsl
#include "common/math.glsl"   // 相対探索 → load_pathsの順に探索
#include <glslkit/pbr.glsl>   // load_pathsのみを探索(相対探索はしない)
```

- 循環includeは `Glslkit::CircularIncludeError`
- `#pragma once` は2回目以降の展開をスキップ(デフォルトは毎回展開)
- `#version` は複数ファイルに散在していても1行目に1回だけ出力し、値が食い違えば
  `Glslkit::VersionConflictError`
- `#if` / `#ifdef` / `#else` / `#endif` は評価せずそのまま出力する(内部の
  `#include` は展開される。これはv0.1の既知の制限)

wasm側でファイルシステムの無い環境向けに `Glslkit::Resolvers::Hash` も同梱している:

```ruby
resolver = Glslkit::Resolvers::Hash.new(
  "pbr.frag" => "...",
  "common/math.glsl" => "..."
)
```

### リフレクション抽出

```ruby
source.reflection.attributes     # => [#<Attribute name="a_position" type="vec3" location=0 array_size=1>, ...]
source.reflection.uniforms       # => [#<Uniform name="u_mvp" type="mat4" setter="uniformMatrix4fv" matrix=true sampler=false ...>, ...]
source.reflection.uniform_blocks # => [#<UniformBlock name="Camera" layout="std140" binding=0>, ...]
source.reflection.outputs        # => [#<Output name="fragColor" type="vec4" location=0>, ...]
```

型からWebGL2のsetterへの対応表は `Glslkit::Types` が唯一の正:

```ruby
Glslkit::Types.setter_for("mat4")  # => "uniformMatrix4fv"
Glslkit::Types.matrix?("mat4")     # => true
Glslkit::Types.sampler?("sampler2D") # => true
```

### マニフェスト生成

vertex/fragmentの `Source` ペアから、`spec/schema/reflection-v1.json`
(Draft 2020-12 JSON Schema) に準拠したマニフェストを組み立てる:

```ruby
manifest = Glslkit::Manifest.new(generated_at: Time.now.utc.iso8601)
manifest.add_program("pbr",
  vertex:   {path: "pbr.vert", source: vertex_source,   url: "/assets/pbr-a1b2.vert"},
  fragment: {path: "pbr.frag", source: fragment_source, url: "/assets/pbr-c3d4.frag"})

manifest.to_json
```

同名uniform/uniform_blockはステージ間で1エントリに統合され、型
(またはlayout/binding)が食い違えば `Glslkit::StageMismatchError` になる。

### Minify

コメント・空白の除去のみを行う(識別子リネームはしない)。改行は一切削除しない
ため、`#line` ディレクティブの行番号や `Reflection` の抽出結果を壊さない:

```ruby
Glslkit::Minifier.minify(source.code)
```

## エラークラス

`Glslkit::IncludeNotFound`, `Glslkit::PathTraversalError`,
`Glslkit::CircularIncludeError`, `Glslkit::VersionConflictError`,
`Glslkit::StageMismatchError`, `Glslkit::UnknownTypeError`

## ライセンス

[MIT](LICENSE.txt)
