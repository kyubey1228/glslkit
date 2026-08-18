# frozen_string_literal: true

module Glslkit
  # 出力される `#line <n> <index>` ディレクティブで使われるファイル
  # インデックスを、各インデックスが指すcanonical_pathに逆引きする。
  #
  # あわせて「平坦化後の出力行 → (元ファイル, 元の行)」の区間マッピングを
  # 保持する(§8.1)。テキスト上の`#line`ディレクティブはこのマッピングを
  # 人間/GLSLコンパイラ向けに描画したものに過ぎず、`line_directives: false`
  # で抑止されていてもこちらは常に記録される。
  class SourceMap
    class UnsupportedVersionError < StandardError; end

    Segment = Struct.new(:output_line, :file_index, :source_line)
    private_constant :Segment

    # spec/schema/source-map-v1.json に対応するHashから復元する(M8g)。
    # `segments` は `output_line` 昇順であることを前提にする(`to_h` は
    # 常にソート済みで出力する)。ソートされていない入力を渡した場合の
    # `resolve` の結果は未定義— 呼び出し側で保証すること。
    def self.from_h(hash)
      version = hash.fetch("version")
      raise UnsupportedVersionError, "unsupported source map version: #{version.inspect}" unless version == 1

      source_map = new
      hash.fetch("files").each { |path| source_map.index_for(path) }
      hash.fetch("segments").each do |output_line, file_index, source_line|
        source_map.add_segment(output_line: output_line, file_index: file_index, source_line: source_line)
      end
      source_map
    end

    def initialize
      @files = []
      @index_by_path = {}
      @segments = []
    end

    attr_reader :files

    # spec/schema/source-map-v1.json に対応するHashを返す。`segments` は
    # 呼び出し順(=Preprocessorがoutput_line昇順で呼ぶ順)を信頼せず、
    # 明示的に `output_line` 昇順にソートしてから出力する。
    def to_h
      {
        "version" => 1,
        "files" => @files,
        "segments" => @segments.sort_by(&:output_line).map { |s| [s.output_line, s.file_index, s.source_line] }
      }
    end

    def index_for(path)
      @index_by_path[path] ||= begin
        @files << path
        @files.size - 1
      end
    end

    # output_line以降、次のadd_segment呼び出しまで(または出力の終わりまで)は
    # file_indexのファイルのsource_line以降に1対1で対応する、という区間を
    # 登録する。呼び出し順はoutput_line昇順であること(Preprocessorはこの順で
    # 呼ぶ)。
    def add_segment(output_line:, file_index:, source_line:)
      @segments << Segment.new(output_line, file_index, source_line)
    end

    # output_lineが属する区間を二分探索し、[canonical_path, source_line]を
    # 返す。どの区間にも属さない(記録前の行、または区間が1つも無い)場合はnil。
    def resolve(output_line)
      segment = segment_for(output_line)
      return nil unless segment

      [@files[segment.file_index], segment.source_line + (output_line - segment.output_line)]
    end

    private

    def segment_for(output_line)
      return nil if @segments.empty?

      index = @segments.bsearch_index { |segment| segment.output_line > output_line }
      index = @segments.size if index.nil?
      return nil if index.zero?

      @segments[index - 1]
    end
  end
end
