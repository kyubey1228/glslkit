# frozen_string_literal: true

require "strscan"
require_relative "types"
require_relative "errors"

module Glslkit
  # 平坦化済み(#include展開後)のGLSLをスキャンして、トップレベルの
  # in/out/uniform宣言を抽出する。これは意図的に本格的なパーサにはしていない:
  # コメントと、プリプロセッサディレクティブ行(#version, #line, #ifdefなど、
  # glslkit自身のPreprocessorが残しうるもの全般)を除去し、{}のネスト深度を
  # 追跡して深度0の宣言以外(関数本体、ブロック本体)をスキップし、深度0の
  # `;`区切り文を1つずつ正規表現でマッチさせる。struct定義、uniform blockの
  # メンバリスト、const/ローカル宣言は意図的にそれ以上パースしない。
  #
  # 各宣言は`output_line`(渡されたcodeの中での行番号)を保持する(§8.1)。
  # ただしこれはあくまで「渡されたcode文字列の中の行番号」であり、元ファイルの
  # 行番号ではない。元ファイルへの変換はGlslkit::SourceMap#resolveの役目で、
  # ReflectionはSourceMapの存在を知らない(責務を分離するため)。
  class Reflection
    Attribute = Struct.new(:name, :type, :location, :array_size, :output_line, keyword_init: true)
    Uniform = Struct.new(:name, :type, :array_size, :setter, :matrix, :sampler, :output_line, keyword_init: true)
    UniformBlock = Struct.new(:name, :layout, :binding, :output_line, keyword_init: true)
    Output = Struct.new(:name, :type, :location, :output_line, keyword_init: true)

    IDENT = /[A-Za-z_]\w*/
    PRECISION = /(?:highp|mediump|lowp)\s+/
    ARRAY_SUFFIX = /(?:\s*\[\s*(\d+)\s*\])?/
    LAYOUT_PREFIX = /(?:layout\s*\(([^)]*)\)\s*)?/

    UNIFORM_BLOCK_PATTERN = /\A#{LAYOUT_PREFIX}uniform\s+(#{IDENT})\s*\{/
    UNIFORM_PATTERN = /\Auniform\s+#{PRECISION}?(#{IDENT})\s+(#{IDENT})#{ARRAY_SUFFIX}\z/
    ATTRIBUTE_PATTERN = /\A#{LAYOUT_PREFIX}in\s+#{PRECISION}?(#{IDENT})\s+(#{IDENT})#{ARRAY_SUFFIX}\z/
    OUTPUT_PATTERN = /\A#{LAYOUT_PREFIX}out\s+#{PRECISION}?(#{IDENT})\s+(#{IDENT})#{ARRAY_SUFFIX}\z/

    attr_reader :attributes, :uniforms, :uniform_blocks, :outputs

    def initialize(code)
      @attributes = []
      @uniforms = []
      @uniform_blocks = []
      @outputs = []

      split_top_level_statements(strip_noise(code)).each do |statement, output_line|
        classify(statement.strip, output_line)
      end
    end

    private

    # コメント・ディレクティブ行を除去するが、行数は必ず保つ(§8.1)。
    # split_top_level_statements が数える行番号は、この除去後のテキストに
    # 対して数える(=コメント除去前後で行数が変わらないことが前提)。
    def strip_noise(code)
      without_comments = code.gsub(%r{//[^\n]*|/\*.*?\*/}m) do |match|
        newlines = match.count("\n")
        newlines.positive? ? ("\n" * newlines) : " "
      end
      without_comments.gsub(/^[ \t]*#.*$/, "")
    end

    # 波括弧の深度が0の時に現れた`;`だけで分割する。これにより関数本体や
    # uniform blockのメンバリスト内の`;`が文の終端として扱われることはない。
    # 深度0に戻る`}`の直後に`;`が続かない場合(つまりuniform blockではなく
    # 関数/制御構文の本体である場合)は、それまで溜めていたものを破棄する。
    #
    # 各要素は [文の本体, 文の(先頭の空白を除いた)開始行番号] のペア。
    def split_top_level_statements(code)
      scanner = StringScanner.new(code)
      statements = []
      buffer = +""
      depth = 0
      line = 1

      until scanner.eos?
        chunk = scanner.scan_until(/[{};]/)
        break if chunk.nil?

        buffer << chunk
        line += chunk.count("\n")

        case chunk[-1]
        when "{"
          depth += 1
        when "}"
          depth -= 1
          buffer = +"" if depth.zero? && !scanner.check(/[ \t\r\n]*;/)
        when ";"
          if depth.zero?
            statements << statement_with_start_line(buffer[0..-2], line)
            buffer = +""
          end
        end
      end

      statements
    end

    # rawの末尾(;を除いた部分)がline行目で終わっているとして、rawの
    # 先頭の空白(改行含む)を除いた実内容が何行目から始まるかを逆算する。
    def statement_with_start_line(raw, end_line)
      leading_whitespace = raw[/\A\s*/]
      start_line = end_line - raw.count("\n") + leading_whitespace.count("\n")
      [raw, start_line]
    end

    def classify(statement, output_line)
      return if statement.empty?

      case statement
      when UNIFORM_BLOCK_PATTERN
        add_uniform_block($~, output_line)
      when UNIFORM_PATTERN
        add_uniform($~, output_line)
      when ATTRIBUTE_PATTERN
        add_attribute($~, output_line)
      when OUTPUT_PATTERN
        add_output($~, output_line)
      end
    end

    def add_uniform_block(match, output_line)
      layout_body = match[1]
      @uniform_blocks << UniformBlock.new(
        name: match[2],
        layout: packing_layout(layout_body),
        binding: qualifier_value(layout_body, "binding"),
        output_line: output_line
      )
    end

    def add_uniform(match, output_line)
      type = match[1]
      @uniforms << Uniform.new(
        name: match[2],
        type: type,
        array_size: (match[3] || 1).to_i,
        setter: Types.setter_for(type),
        matrix: Types.matrix?(type),
        sampler: Types.sampler?(type),
        output_line: output_line
      )
    end

    def add_attribute(match, output_line)
      @attributes << Attribute.new(
        name: match[3],
        type: match[2],
        location: qualifier_value(match[1], "location"),
        array_size: (match[4] || 1).to_i,
        output_line: output_line
      )
    end

    def add_output(match, output_line)
      @outputs << Output.new(
        name: match[3],
        type: match[2],
        location: qualifier_value(match[1], "location"),
        output_line: output_line
      )
    end

    def qualifier_value(layout_body, key)
      return nil unless layout_body

      m = layout_body.match(/\b#{key}\s*=\s*(\d+)/)
      m && m[1].to_i
    end

    def packing_layout(layout_body)
      return "shared" unless layout_body

      m = layout_body.match(/\b(std140|std430|shared|packed)\b/)
      m ? m[1] : "shared"
    end
  end
end
