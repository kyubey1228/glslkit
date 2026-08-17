# frozen_string_literal: true

require_relative "../errors"

module Glslkit
  module Resolvers
    # {request => content} というフラットなHashを直接引くだけ。ファイル
    # システムを持たないwasm側ランタイムやテストで使う。`from`はインタ
    # フェースの形を合わせるために受け取るが無視する。ディレクトリ構造が
    # 存在しないため、相対解決のしようがない。
    class Hash
      def initialize(files)
        @files = files
      end

      def read(request, from: nil)
        content = @files[request]
        raise IncludeNotFound, "no such include: #{request.inspect}" unless content

        [request, content]
      end
    end
  end
end
