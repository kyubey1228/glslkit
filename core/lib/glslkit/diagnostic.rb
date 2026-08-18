# frozen_string_literal: true

module Glslkit
  # 検証結果1件分(§8.2)。file/lineの解決はValidatorの役目であり、
  # DiagnosticやReflection自身は関与しない。
  Diagnostic = Struct.new(:severity, :code, :message, :program, :stage, :name, :file, :line, keyword_init: true) do
    def error?
      severity == :error
    end

    def warning?
      severity == :warning
    end

    def to_s
      "[#{code}] #{location}: #{message}"
    end

    private

    def location
      return "#{file}:#{line}" if file

      stage ? "#{program}(#{stage})" : program.to_s
    end
  end
end
