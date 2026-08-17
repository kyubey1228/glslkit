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

## ライセンス

[MIT](LICENSE.txt)
