# frozen_string_literal: true

require "strscan"
require_relative "types"
require_relative "errors"

module Glslkit
  # Scans flattened (post-#include) GLSL for top-level in/out/uniform
  # declarations. This is intentionally not a real parser: it strips
  # comments and preprocessor directive lines (#version, #line, #ifdef, ...
  # anything glslkit's own Preprocessor may have left behind), tracks {}
  # nesting depth to skip anything that isn't a depth-0 declaration (function
  # bodies, block bodies), then regex-matches each depth-0 `;`-terminated
  # statement individually. struct definitions, uniform block member lists,
  # and const/local declarations are deliberately not parsed further.
  class Reflection
    Attribute = Struct.new(:name, :type, :location, :array_size, keyword_init: true)
    Uniform = Struct.new(:name, :type, :array_size, :setter, :matrix, :sampler, keyword_init: true)
    UniformBlock = Struct.new(:name, :layout, :binding, keyword_init: true)
    Output = Struct.new(:name, :type, :location, keyword_init: true)

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

      split_top_level_statements(strip_noise(code)).each { |statement| classify(statement.strip) }
    end

    private

    def strip_noise(code)
      without_comments = code.gsub(%r{//[^\n]*|/\*.*?\*/}m, " ")
      without_comments.gsub(/^[ \t]*#.*$/, "")
    end

    # Splits on `;` seen at brace-depth 0 only, so semicolons inside function
    # bodies or uniform block member lists never end a statement. A depth-0
    # closing `}` NOT immediately followed by `;` (i.e. a function/control
    # body, not a uniform block) discards whatever had been accumulating.
    def split_top_level_statements(code)
      scanner = StringScanner.new(code)
      statements = []
      buffer = +""
      depth = 0

      until scanner.eos?
        chunk = scanner.scan_until(/[{};]/)
        break if chunk.nil?

        buffer << chunk
        case chunk[-1]
        when "{"
          depth += 1
        when "}"
          depth -= 1
          buffer = +"" if depth.zero? && !scanner.check(/[ \t\r\n]*;/)
        when ";"
          if depth.zero?
            statements << buffer[0..-2]
            buffer = +""
          end
        end
      end

      statements
    end

    def classify(statement)
      return if statement.empty?

      case statement
      when UNIFORM_BLOCK_PATTERN
        add_uniform_block($~)
      when UNIFORM_PATTERN
        add_uniform($~)
      when ATTRIBUTE_PATTERN
        add_attribute($~)
      when OUTPUT_PATTERN
        add_output($~)
      end
    end

    def add_uniform_block(match)
      layout_body = match[1]
      @uniform_blocks << UniformBlock.new(
        name: match[2],
        layout: packing_layout(layout_body),
        binding: qualifier_value(layout_body, "binding")
      )
    end

    def add_uniform(match)
      type = match[1]
      @uniforms << Uniform.new(
        name: match[2],
        type: type,
        array_size: (match[3] || 1).to_i,
        setter: Types.setter_for(type),
        matrix: Types.matrix?(type),
        sampler: Types.sampler?(type)
      )
    end

    def add_attribute(match)
      @attributes << Attribute.new(
        name: match[3],
        type: match[2],
        location: qualifier_value(match[1], "location"),
        array_size: (match[4] || 1).to_i
      )
    end

    def add_output(match)
      @outputs << Output.new(
        name: match[3],
        type: match[2],
        location: qualifier_value(match[1], "location")
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
