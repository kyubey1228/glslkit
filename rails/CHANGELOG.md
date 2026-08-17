# Changelog

## [Unreleased]

初回リリース (v0.1)。

### 追加

- `.glsl` / `.vert` / `.frag` をPropshaftのアセットとして登録
  (content_type: `x-shader/x-vertex` / `x-shader/x-fragment` / `text/plain`)
- `Glslkit::Rails::Compiler` — Propshaft経由で `#include` を解決した内容を配信
  (developmentは毎リクエスト再処理、productionは`assets:precompile`時に1回)
- `rake glslkit:reflect` と `assets:precompile` フックによる
  `glsl-manifest.json` の自動生成
- `Glslkit::Rails.manifest` — Ruby側からの読み取り窓口 (productionはメモ化)
- `glsl_script_tag` / `glsl_manifest_tag` ビューヘルパー
  (`</script>`エスケープ、CSP nonce対応)
