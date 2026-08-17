# frozen_string_literal: true

module Glslkit
  # Maps the file indices used in emitted `#line <n> <index>` directives
  # back to the canonical_path each index refers to.
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
