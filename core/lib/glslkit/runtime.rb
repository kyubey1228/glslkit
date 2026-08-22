# frozen_string_literal: true

# マニフェストの読み込みと SourceMap の復元だけに必要な、狭い入口(M8g)。
# ruby.wasm 上の消費側(glslkit-webgl 等)からはこちらを require すること。
#
# `glslkit/preprocessor` / `glslkit/reflection` / `glslkit/minifier` /
# `glslkit/digest` は意図的にロードしない。ビルド用途(前処理・解析・
# digest計算)は従来通り `require "glslkit"`(core/lib/glslkit.rb)を使うこと。
#
# `glslkit/diagnostic` は例外(M11d、Context#reload_programの戻り値が使う)。
# stdlib依存も他ファイルへのrequireも無いプレーンなStructなので、狭い入口の
# 制約(File/Dir/digestを持ち込まない)を破らない。
require_relative "errors"
require_relative "types"
require_relative "source_map"
require_relative "manifest"
require_relative "diagnostic"

module Glslkit
end
