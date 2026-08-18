# frozen_string_literal: true

require_relative "diagnostic"

module Glslkit
  # Glslkit::Program(§8.3)を1つ受け取り、単一ステージで完結する検証ルールを
  # 実行する。マージ前のReflectionを直接見るため、Manifestが統合してしまう
  # 情報(同一ステージ内の重複など)も検出できる。例外は投げず、診断の配列を
  # 常に返す。
  class Validator
    class Result
      def initialize(diagnostics)
        @diagnostics = diagnostics
      end

      attr_reader :diagnostics

      def errors
        diagnostics.select(&:error?)
      end

      def warnings
        diagnostics.select(&:warning?)
      end

      def ok?
        errors.empty?
      end
    end

    def initialize(disabled: [])
      @disabled = disabled.map(&:to_s)
    end

    def validate(program)
      diagnostics = []
      diagnostics.concat(check_attribute_location_collisions(program)) if enabled?("E004")
      diagnostics.concat(check_output_location_collisions(program)) if enabled?("E005")
      diagnostics.concat(check_duplicate_names_within_a_stage(program)) if enabled?("E006")
      diagnostics.concat(check_reserved_gl_prefix(program)) if enabled?("E007")
      Result.new(diagnostics)
    end

    private

    def enabled?(code)
      !@disabled.include?(code)
    end

    # attributeはvertexステージにしか存在しない(SPEC.md §4のManifest決定)。
    def check_attribute_location_collisions(program)
      stage = :vertex
      source = program.sources[stage]
      return [] unless source

      duplicate_groups_by(source.reflection.attributes, &:location).flat_map do |location, entries|
        message = "attribute location #{location} is used by #{entries.map(&:name).join(", ")}"
        [group_diagnostic(program, stage, source, "E004", entries, message)]
      end
    end

    # outputはfragmentステージにしか存在しない(同上)。
    def check_output_location_collisions(program)
      stage = :fragment
      source = program.sources[stage]
      return [] unless source

      duplicate_groups_by(source.reflection.outputs, &:location).flat_map do |location, entries|
        message = "output location #{location} is used by #{entries.map(&:name).join(", ")}"
        [group_diagnostic(program, stage, source, "E005", entries, message)]
      end
    end

    # GLSLの識別子はattribute/uniform/uniform block/outputを問わず1つの
    # 名前空間を共有するため、種類をまたいで同名かどうかをチェックする。
    def check_duplicate_names_within_a_stage(program)
      Program::STAGES.flat_map do |stage|
        source = program.sources[stage]
        next [] unless source

        duplicate_groups_by(all_declarations(source.reflection), &:name).flat_map do |name, entries|
          [group_diagnostic(program, stage, source, "E006", entries, "\"#{name}\" is declared more than once")]
        end
      end
    end

    def check_reserved_gl_prefix(program)
      Program::STAGES.flat_map do |stage|
        source = program.sources[stage]
        next [] unless source

        all_declarations(source.reflection).select { |entry| entry.name.start_with?("gl_") }.map do |entry|
          message = "\"#{entry.name}\" starts with the reserved prefix \"gl_\""
          build_diagnostic(program, stage, source, "E007", entry.name, entry.output_line, message)
        end
      end
    end

    def all_declarations(reflection)
      reflection.attributes + reflection.uniforms + reflection.uniform_blocks + reflection.outputs
    end

    # yieldした値がnilのエントリは無視する(未指定location同士を衝突扱いに
    # しないため)。出現順を保ったまま、2件以上あるグループだけを返す。
    def duplicate_groups_by(entries)
      groups = Hash.new { |h, k| h[k] = [] }
      entries.each do |entry|
        key = yield entry
        groups[key] << entry unless key.nil?
      end
      groups.select { |_key, group| group.size > 1 }
    end

    def group_diagnostic(program, stage, source, code, entries, message)
      anchor = entries.min_by(&:output_line)
      build_diagnostic(program, stage, source, code, nil, anchor.output_line, message)
    end

    def build_diagnostic(program, stage, source, code, name, output_line, message)
      file, line = source.source_map&.resolve(output_line) || [nil, nil]
      Diagnostic.new(
        severity: :error,
        code: code,
        message: message,
        program: program.name,
        stage: stage,
        name: name,
        file: file,
        line: line
      )
    end
  end
end
