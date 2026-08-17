# Changelog

## [Unreleased]

初回リリース (v0.1)。

### 追加

- `Glslkit::Preprocessor` — `#include`解決、`#pragma once`、`#version`/`#extension`の
  集約と衝突検出、`#line`ディレクティブ挿入、循環include検出
- `Glslkit::Resolvers::FileSystem` / `Glslkit::Resolvers::Hash`
- `Glslkit::Reflection` — attribute / uniform / uniform_block / output の抽出
- `Glslkit::Types` — GLSL型 → WebGL2 setter の対応表
- `Glslkit::Manifest` — `spec/schema/reflection-v1.json` (Draft 2020-12) に
  準拠したマニフェスト生成。ステージ間のuniform/uniform_block統合
- `Glslkit::Minifier` — コメント・空白のみの除去 (識別子リネームなし)
- `Glslkit::SourceMap` / `Glslkit::Source`
