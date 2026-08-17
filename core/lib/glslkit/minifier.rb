# frozen_string_literal: true

module Glslkit
  # コメントと不要な空白のみを除去する — 識別子のリネームも行数のマージも
  # しない。プリプロセッサディレクティブ(#version, #line, #ifdefなど)は
  # それぞれ独立した1物理行でなければならないため、改行は一切削除しない:
  # 入力の各行は必ず出力のちょうど1行に対応するので、コード中に既にある
  # #lineディレクティブの行番号は正しいまま保たれ、Reflectionの抽出結果も
  # 変化しない。
  module Minifier
    COMMENT_PATTERN = %r{//[^\n]*|/\*.*?\*/}m

    module_function

    def minify(code)
      strip_comments(code).each_line.map { |line| minify_line(line) }.join
    end

    def strip_comments(code)
      code.gsub(COMMENT_PATTERN) do |match|
        newlines = match.count("\n")
        # 改行を含まないコメントでも、区切りは残しておく必要がある。
        # 例えば `vec3/* x */foo` が `vec3foo` になってしまわないように。
        newlines.positive? ? ("\n" * newlines) : " "
      end
    end

    def minify_line(line)
      ending = line.end_with?("\n") ? "\n" : ""
      "#{line.chomp.strip.gsub(/[ \t]+/, " ")}#{ending}"
    end
  end
end
