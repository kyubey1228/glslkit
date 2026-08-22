# frozen_string_literal: true

module Glslkit
  module WebGL
    class Error < StandardError; end
    class UnsupportedError < Error; end
    class UnknownProgramError < Error; end
    class UnknownUniformError < Error; end
    class UniformLengthError < Error; end
    class ShaderError < Error; end
    # M11d: reload_program(SPEC-livereload.md §4.2)で新旧のattribute location
    # が一致しない場合に投げる。既存のVAOをそのまま使い続けると壊れた描画に
    # なるため、無言で続行せずページのリロードを促す。
    class ReloadIncompatibleError < Error; end

    class CompileError < ShaderError
      attr_reader :stage, :file, :line, :raw_log

      def initialize(stage:, raw_log:, file: nil, line: nil, detail: nil)
        @stage = stage
        @file = file
        @line = line
        @raw_log = raw_log.to_s
        message = detail || @raw_log
        message = "#{file}:#{line}: #{message}" if file && line
        super(message)
      end
    end

    class LinkError < ShaderError
      attr_reader :raw_log

      def initialize(raw_log)
        @raw_log = raw_log.to_s
        super(@raw_log)
      end
    end
  end
end
