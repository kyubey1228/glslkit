# frozen_string_literal: true

module Glslkit
  # 出力される `#line <n> <index>` ディレクティブで使われるファイル
  # インデックスを、各インデックスが指すcanonical_pathに逆引きする。
  class SourceMap
    def initialize
      @files = []
      @index_by_path = {}
    end

    attr_reader :files

    def index_for(path)
      @index_by_path[path] ||= begin
        @files << path
        @files.size - 1
      end
    end
  end
end
