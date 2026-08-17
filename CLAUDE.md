# glslkit

GLSLの `#include` 展開とuniform/attribute/outputのリフレクション抽出を行うRuby gem。
将来 ruby.wasm 上のWebGLバインディングが `spec/schema/reflection-v1.json` を契約として
リフレクションJSONを消費する構想があるため、コアgemは依存ゼロ・wasm可搬性を最優先する。

**唯一の正典は `SPEC.md`。** ここに書く内容と食い違ったら `SPEC.md` を優先し、疑わしければ質問すること。
`SPEC.md` の「決定事項」は勝手に変更しない。

## リポジトリ構成

1リポジトリ・2gem。`core/` (glslkit) はwasmにバンドルされる想定なので、
`rails/` (glslkit-rails) の依存やコードを一切持ち込まない。

```
core/   glslkit         — 依存ゼロ (stdlibのjson/strscan/setのみ)
rails/  glslkit-rails    — glslkit, railties >= 7.1 に依存
spec/schema/             — reflection-v1.json (JSON Schema Draft 2020-12)。両環境をつなぐ契約面
```

## 厳守事項

- `core/` で `activesupport` を require しない。追加したくなったら必ず相談する。
- `core/` で `File` / `Dir` をモジュールのトップレベルから直接触らない。
  ファイルI/Oは `Glslkit::Resolvers::FileSystem` に閉じ込める。
- Ruby >= 3.1。テストは minitest。Lintは standardrb。
- `Glslkit::Rails` 名前空間の中では素の `Rails` は `Glslkit::Rails` 自身に解決される
  (Rubyの定数探索の罠)。フレームワークを指すときは常に `::Rails` と書く。

## よく使うコマンド

```
bundle install
bundle exec rake            # core + rails 両方のテスト
bundle exec rake test_core
bundle exec rake test_rails
bundle exec standardrb
```

## 実装順序

`SPEC.md` §6 のマイルストーン順 (M0〜M7) を厳守し、各マイルストーンごとにコミットを分けて
テストが緑になってから次に進む。**M1 (Typesテーブル + reflection-v1.json スキーマ) が最優先。**
スキーマは実装前に内容を提示して確認を取ること。

## 判断に迷ったら

- GLSLの構文解釈で迷ったら推測実装せず質問する。
- 正規表現ベースのReflection抽出が複雑化してきたら設計見直しのサインなので報告する。
