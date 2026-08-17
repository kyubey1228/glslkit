# frozen_string_literal: true

module Glslkit
  # Strips comments and insignificant whitespace only — no identifier
  # renaming, no line merging. Preprocessor directives (#version, #line,
  # #ifdef, ...) must each stay alone on their own physical line, so this
  # never removes a newline: every input line maps to exactly one output
  # line, which keeps any #line directives already in the code numerically
  # correct and leaves Reflection's output unchanged.
  module Minifier
    COMMENT_PATTERN = %r{//[^\n]*|/\*.*?\*/}m

    module_function

    def minify(code)
      strip_comments(code).each_line.map { |line| minify_line(line) }.join
    end

    def strip_comments(code)
      code.gsub(COMMENT_PATTERN) do |match|
        newlines = match.count("\n")
        # A comment with no newline still needs to leave a separator behind
        # so e.g. `vec3/* x */foo` doesn't become `vec3foo`.
        newlines.positive? ? ("\n" * newlines) : " "
      end
    end

    def minify_line(line)
      ending = line.end_with?("\n") ? "\n" : ""
      "#{line.chomp.strip.gsub(/[ \t]+/, " ")}#{ending}"
    end
  end
end
