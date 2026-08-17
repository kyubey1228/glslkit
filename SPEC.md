# glslkit — 実装仕様書 (v0.1)

> Claude Code への指示書。この文書の「決定事項」は勝手に変更しないこと。
> 判断に迷う箇所は実装を止めて質問すること。

---

## 0. 目的とスコープ

GLSLソースをRubyで前処理・解析し、**ビルド時に得たリフレクション情報を成果物として残す**ライブラリ。

将来的に ruby.wasm 上のWebGLバインディングがこのリフレクションJSONを消費して、
実行時の `getActiveUniform` ループを不要にする。**v0.1ではwasm側は実装しない**が、
そのための契約面（リフレクションJSONスキーマ）を確定させることがv0.1の最重要目的。

### v0.1 のゴール

1. `#include` を解決してGLSLを1ファイルに平坦化できる
2. uniform / attribute / output / uniform block を抽出してJSONに出力できる
3. Rails (Propshaft) のアセットパイプラインに載る

### 非ゴール（v0.1では作らない）

- ruby.wasm ランタイム、WebGLバインディング
- 完全なGLSL AST パーサ
- 識別子リネームを伴うminify（コメント・空白除去のみ行う）
- `#if` / `#ifdef` の評価（後述の通りパススルー）
- WGSL / SPIR-V

---

## 1. リポジトリ構成

**1リポジトリ・2gem** とする。同居させない理由は、コアが ruby.wasm にバンドルされる際に
Rails側のコードと依存を持ち込ませないため。

```
glslkit/
├── core/
│   ├── glslkit.gemspec
│   ├── lib/glslkit.rb
│   ├── lib/glslkit/...
│   └── test/
├── rails/
│   ├── glslkit-rails.gemspec
│   ├── lib/glslkit/rails.rb
│   ├── lib/glslkit/rails/...
│   └── test/
├── spec/schema/reflection-v1.json   # JSON Schema (Draft 2020-12)
├── Gemfile                          # 開発用。両gemをpath指定
├── Rakefile                         # 両方のテストを回す
├── CLAUDE.md
└── README.md
```

### 依存制約（厳守）

| gem | 実行時依存 |
|---|---|
| `glslkit` (core) | **なし**。stdlibの `json` `strscan` `set` のみ |
| `glslkit-rails` | `glslkit`, `railties >= 7.1` |

- コアで **activesupport を require してはならない**。wasmバイナリサイズに直結する。
  `camelize` 等が必要なら自前で書く。
- コアで `File` / `Dir` を **モジュールのトップレベルから触ってはならない**。
  ファイルI/Oは `Glslkit::Resolvers::FileSystem` に閉じ込める。
- Ruby >= 3.1
- テストは **minitest**（stdlib、依存を増やさないため）
- Lint は standardrb

---

## 2. コア API

### 2.1 全体の流れ

```ruby
resolver = Glslkit::Resolvers::FileSystem.new(load_paths: ["app/shaders"])
source   = Glslkit::Preprocessor.new(resolver: resolver).process("pbr.frag")
# => Glslkit::Source

source.code        # => 平坦化済みGLSL (String)
source.reflection  # => Glslkit::Reflection
source.source_map  # => Glslkit::SourceMap
source.digest      # => SHA256 hex (String)
```

### 2.2 `Glslkit::Resolver` (抽象インタフェース)

Rails側とwasm側の差を吸収する唯一の接点。**ダックタイピングで定義し、継承を強制しない。**

```ruby
# 実装すべきメソッド
#   read(request, from:) -> [canonical_path(String), content(String)]
#     request : #include に書かれた文字列 (例 "common/math.glsl")
#     from    : 呼び出し元の canonical_path。エントリポイントでは nil
#   見つからない場合は Glslkit::IncludeNotFound を raise すること
```

同梱する実装:

- `Glslkit::Resolvers::FileSystem.new(load_paths:)`
  - `from` からの相対 → load_paths の順に探索
  - load_paths の外に出るパス（`../` によるエスケープ）は `Glslkit::PathTraversalError`
- `Glslkit::Resolvers::Hash.new(files)`
  - `{"pbr.frag" => "...", "common/math.glsl" => "..."}` を引くだけ。wasm側とテスト用

### 2.3 `Glslkit::Preprocessor`

#### include の構文

```glsl
#include "common/math.glsl"
#include <glslkit/pbr.glsl>   // <> はライブラリ検索（load_paths のみ、相対探索しない）
```

#### 決定事項

- **循環include**: 検出したら `Glslkit::CircularIncludeError` を raise。
  例外メッセージに `a.glsl -> b.glsl -> c.glsl -> a.glsl` の形でチェーンを含めること。
- **重複include**: C同様、デフォルトは毎回展開する。
  `#pragma once` があるファイルは2回目以降スキップする。
- **`#version`**: 出力の必ず1行目。全includeツリーから収集し、
  - 0個 → 何も出力しない
  - 1種類のみ → それを1行目に出力
  - 複数の異なる値 → `Glslkit::VersionConflictError`
- **`#extension`**: `#version` の直後にまとめて出力。同一内容は重複排除。
- **`#line` の挿入**: 展開後の各ブロック先頭に `#line <行番号> <ファイルインデックス>` を挿入し、
  ブラウザのコンパイルエラーを元ファイルに戻せるようにする。
  ファイルインデックスと実パスの対応は `SourceMap#files` に保持する。
  - `#version 300 es` 未満の環境では第2引数が使えないため、
    `Preprocessor.new(line_directives: false)` で抑止できるようにすること。
- **`#if` / `#ifdef` / `#else` / `#endif`**: **評価しない。そのまま出力する。**
  ただし条件ブロック内の `#include` は展開する（これはv0.1の既知の制限としてREADMEに明記）。

### 2.4 `Glslkit::Reflection`

平坦化後のソースをスキャンして宣言を抽出する。**完全なパーサは作らない**。
以下の手順で行うこと:

1. コメント除去（`//`、`/* */`。文字列リテラルはGLSLに無いので考慮不要）
2. `{}` のネスト深度を追跡し、**深度0の宣言のみ**を対象にする（関数ローカル変数を誤検出しないため）
3. `;` 単位で区切って1宣言ずつ正規表現でマッチ

抽出対象と、対応する構文:

```glsl
layout(location = 0) in vec3 a_position;      // attribute (location 明示)
in vec2 a_uv;                                  // attribute (location 未指定 → null)
uniform mat4 u_model_view;                     // uniform
uniform highp sampler2D u_albedo;              // precision修飾子を許容
uniform vec4 u_lights[8];                      // 配列 → array_size: 8
layout(std140) uniform Camera { ... };         // uniform block
out vec4 fragColor;                            // output
layout(location = 0) out vec4 gAlbedo;         // output (MRT)
```

- `struct` 定義、`uniform` ブロックのメンバ分解は **v0.1では行わない**。
  uniform block は名前・レイアウト・binding のみ記録する。
- `const` / ローカル `in`/`out`（関数引数）は無視すること。

### 2.5 型 → WebGL setter のマッピング

**このテーブルはコアが唯一の正とする。** wasm側が参照する。
`Glslkit::Types.setter_for("mat4")` の形で引けること。

| GLSL型 | setter | 備考 |
|---|---|---|
| `float` | `uniform1fv` | |
| `vec2` `vec3` `vec4` | `uniform2fv` `uniform3fv` `uniform4fv` | |
| `int` `bool` | `uniform1iv` | |
| `ivec2..4` `bvec2..4` | `uniform2iv`..`uniform4iv` | |
| `uint` | `uniform1uiv` | |
| `uvec2..4` | `uniform2uiv`..`uniform4uiv` | |
| `mat2` `mat3` `mat4` | `uniformMatrix2fv` `uniformMatrix3fv` `uniformMatrix4fv` | transpose引数が必要 |
| `mat2x3` 等の非正方 | `uniformMatrix2x3fv` 等 | |
| `sampler2D` `samplerCube` `sampler3D` `sampler2DArray` およびその `i`/`u` 変種、`sampler2DShadow` | `uniform1iv` | `sampler: true` フラグを立てる |

- スカラー版（`uniform1f`）ではなく **一律 `v` 版を採用**する。呼び出し側の分岐を減らすため。
- 行列は `matrix: true` フラグを立て、wasm側が transpose 引数の有無を判断できるようにする。
- 未知の型は `Glslkit::UnknownTypeError`。

---

## 3. リフレクションJSON スキーマ (v1)

**これが2つの実行環境をつなぐ契約面。ここを最初に固めること。**
`spec/schema/reflection-v1.json` に JSON Schema として置き、テストで検証する。

```json
{
  "schema_version": 1,
  "generated_at": "2026-08-17T00:00:00Z",
  "programs": {
    "pbr": {
      "digest": "3f9a...",
      "stages": {
        "vertex":   { "path": "pbr.vert", "digest": "a1b2...", "url": "/assets/pbr-a1b2.vert" },
        "fragment": { "path": "pbr.frag", "digest": "c3d4...", "url": "/assets/pbr-c3d4.frag" }
      },
      "attributes": [
        { "name": "a_position", "type": "vec3", "location": 0, "array_size": 1 },
        { "name": "a_uv",       "type": "vec2", "location": null, "array_size": 1 }
      ],
      "uniforms": [
        { "name": "u_model_view", "type": "mat4", "array_size": 1,
          "setter": "uniformMatrix4fv", "matrix": true, "sampler": false, "stages": ["vertex"] },
        { "name": "u_albedo", "type": "sampler2D", "array_size": 1,
          "setter": "uniform1iv", "matrix": false, "sampler": true, "stages": ["fragment"] },
        { "name": "u_lights", "type": "vec4", "array_size": 8,
          "setter": "uniform4fv", "matrix": false, "sampler": false, "stages": ["fragment"] }
      ],
      "uniform_blocks": [
        { "name": "Camera", "layout": "std140", "binding": 0, "stages": ["vertex", "fragment"] }
      ],
      "outputs": [
        { "name": "fragColor", "type": "vec4", "location": 0 }
      ]
    }
  }
}
```

### 決定事項

- `programs` のキー = プログラム名。同名の `.vert` / `.frag` ペアから自動導出する。
- 同名uniformが複数ステージに現れた場合は **1エントリに統合**し `stages` に両方を入れる。
  型が食い違う場合は `Glslkit::StageMismatchError`。
- 配列でないものも `array_size: 1` とする（消費側の分岐を減らすため）。
- `location: null` は「WebGL側で `getAttribLocation` を引く必要がある」ことを意味する。
- 未使用uniformはGLSLコンパイラに削除され得るため、
  **wasm側は location 解決失敗を許容する必要がある**旨をスキーマのdescriptionに書いておくこと。
- `stages.*.url` は **Propshaftが計算するフィンガープリント付きアセットパス**であり、
  glslkitのdigest（`source.digest` やプログラム全体の `digest`）から合成するものではない。
  両者は無関係な値なので、Manifest側は `url` を外部から渡された文字列としてそのまま格納するだけにし、
  digestから逆算・生成しようとしないこと。

---

## 4. Rails アダプタ (`glslkit-rails`)

### 4.1 Propshaft 統合

- 拡張子 `.glsl` `.vert` `.frag` を Propshaft の対象に登録
- content type は `x-shader/x-vertex` / `x-shader/x-fragment` / `text/plain`
- Compiler を登録して `#include` を解決した内容を配信する
- resolver は Propshaft の load_path から構築する
- development: 毎リクエスト再処理（キャッシュしない）
- production: `assets:precompile` 時に1回

### 4.2 マニフェスト生成

- `assets:precompile` にフックして `public/assets/glsl-manifest.json` を出力
- `rake glslkit:reflect` で単体実行もできること
- `Glslkit::Rails.manifest` でRuby側から読めること（production ではメモ化）

### 4.3 ビューヘルパ

```erb
<%= glsl_script_tag "pbr.vert" %>
<%# => <script type="x-shader/x-vertex" id="pbr-vert">...</script> （インライン埋め込み） %>

<%= glsl_manifest_tag %>
<%# => <script type="application/json" id="glsl-manifest">...</script> %>
```

- インライン埋め込みは `</script>` を含む可能性を考慮してエスケープすること
- CSP nonce に対応すること（`content_security_policy_nonce`）

### 4.4 設定

```ruby
# config/application.rb
config.glslkit.paths = ["app/shaders"]          # デフォルト: app/shaders
config.glslkit.minify = Rails.env.production?
config.glslkit.line_directives = !Rails.env.production?
config.glslkit.manifest_path = "glsl-manifest.json"
```

---

## 5. テスト要件

fixture は `test/fixtures/shaders/` に置く。**以下のケースは必ずテストを書くこと。**

### Preprocessor
- 単純include / ネストしたinclude / 相対パス解決
- `<>` 形式が相対探索をしないこと
- 循環include → 例外、メッセージにチェーンが含まれる
- `#pragma once` が2回目をスキップする
- `#version` が複数ファイルに散在 → 1行目に1回だけ出る
- `#version` の値が衝突 → 例外
- include先が存在しない → `IncludeNotFound`
- `../../etc/passwd` 的なパス → `PathTraversalError`
- `#line` の行番号が元ファイルと一致する（ゴールデンファイル比較）

### Reflection
- 各型のsetterマッピング全網羅（テーブル駆動）
- 関数内のローカル変数を拾わないこと
- `layout(location = N)` の有無
- 配列uniform
- MRT（複数`out`）
- コメント内の `uniform` を拾わないこと
- 複数行にまたがる宣言

### Manifest
- 生成JSONが JSON Schema を満たすこと
- 2ステージ間のuniform統合
- 型不一致 → `StageMismatchError`
- 同じ入力から同じdigestが出ること（決定性）

### Rails
- ダミーRailsアプリで `assets:precompile` が通り manifest が出る
- ヘルパの出力（nonce有無の両方）

---

## 6. 実装順序

各マイルストーンごとにコミットを分け、テストが緑になってから次へ進むこと。

| # | 内容 | 完了条件 |
|---|---|---|
| M0 | リポジトリ骨組み、2つのgemspec、Rakefile、CI (GitHub Actions) | `rake` が空テストで通る |
| M1 | `Types` テーブルと `spec/schema/reflection-v1.json` | スキーマ単体のバリデーションテストが通る |
| M2 | `Resolver` 2実装 + `Preprocessor` | §5 Preprocessor の全テストが緑 |
| M3 | `Reflection` + `SourceMap` | §5 Reflection の全テストが緑 |
| M4 | `Manifest` シリアライザ | 生成JSONがM1のスキーマを満たす |
| M5 | `Minifier`（コメント・空白除去のみ） | 除去後もリフレクション結果が不変であること |
| M6 | `glslkit-rails` | ダミーアプリのテストが緑 |
| M7 | README、CHANGELOG、使用例 | — |

**M1を最優先で確定させること。** ここが後続すべての前提になる。

---

## 7. Claude Code への注意

- 実装前に `spec/schema/reflection-v1.json` の内容を提示して確認を取ること
- GLSLの構文で判断に迷ったら、推測で実装せず質問すること
- 正規表現が複雑化してきたら、それは設計の見直しサイン。報告すること
- `activesupport` を追加したくなったら必ず止まって相談すること
- gem名 `glslkit` / `glslkit-rails` は RubyGems.org で空きを確認してから確定すること
