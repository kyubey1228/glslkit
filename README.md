# glslkit

GLSLソースをRubyで前処理・解析し、ビルド時に得たリフレクション情報（uniform /
attribute / output / uniform block）を成果物として残すライブラリ。

- `#include` を解決してGLSLを1ファイルに平坦化する
- uniform / attribute / output / uniform block を抽出してJSONマニフェストに出力する
- Rails (Propshaft) のアセットパイプラインに載る

将来、[ruby.wasm](https://github.com/ruby/ruby.wasm) 上のWebGLバインディングが
このリフレクションJSONを消費して、実行時の `getActiveUniform` ループを不要にする
ことを見据えている。v0.1ではwasm側は実装しないが、そのための契約面
（[リフレクションJSONスキーマ](spec/schema/reflection-v1.json)）を確定させることが
最重要目的。

## 構成

1リポジトリ・2gem構成。コアが将来 ruby.wasm にバンドルされる際、Rails側の
コードと依存を持ち込まないための分離。

| gem | ディレクトリ | 実行時依存 | 内容 |
|---|---|---|---|
| [`glslkit`](core) | `core/` | なし | `#include`解決、リフレクション抽出、マニフェスト生成、minify |
| [`glslkit-rails`](rails) | `rails/` | `glslkit`, `railties >= 7.1`, `propshaft >= 1.3.2` | Propshaft統合、ビューヘルパー |

```
glslkit/
├── core/                             # gem: glslkit
├── rails/                            # gem: glslkit-rails
├── spec/schema/reflection-v1.json    # JSON Schema (Draft 2020-12)
└── SPEC.md                           # 実装仕様書
```

使い方はそれぞれの gem の README を参照:

- [core/README.md](core/README.md) — `#include`解決、リフレクション抽出、マニフェスト生成、minify
- [rails/README.md](rails/README.md) — Propshaft統合、ビューヘルパー、rakeタスク

## 開発

```
bundle install
bundle exec rake            # core + rails 両方のテスト
bundle exec rake test_core
bundle exec rake test_rails
bundle exec standardrb
```

Ruby >= 3.1。テストはminitest、Lintはstandardrb。

## ライセンス

[MIT](LICENSE)
