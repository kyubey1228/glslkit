# frozen_string_literal: true

module Glslkit
  # #include のリクエストを解決するダックタイピングのインタフェース。継承を
  # 強制するものではない — 下の Glslkit::Resolvers::FileSystem と ::Hash は
  # 単にこれと同じメソッド形状を実装しているだけ。Railsや将来のruby.wasm側の
  # resolverも同じ形状に合わせればよい。
  #
  #   read(request, from:) -> [canonical_path, content]
  #
  #     request        - #include の後に書かれた文字列。例 "common/math.glsl"
  #     from            - 呼び出し元(includeした側)のcanonical_path。
  #                       エントリポイントではnil (`#include <...>` の場合も
  #                       常にnilを渡し、相対探索を完全にスキップさせる)
  #     canonical_path  - 解決したファイルを表す、load_path相対の安定した
  #                       識別子 (循環検出、#pragma once、
  #                       Glslkit::SourceMap#files で使う)
  #
  #   requestが解決できない場合は Glslkit::IncludeNotFound を raise すること。
  module Resolver
  end
end
