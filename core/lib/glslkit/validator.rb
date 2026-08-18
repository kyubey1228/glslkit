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
      diagnostics.concat(check_out_in_correspondence(program))
      diagnostics.concat(check_cross_stage_uniform_mismatch(program)) if enabled?("E003")
      diagnostics.concat(check_attribute_location_collisions(program)) if enabled?("E004")
      diagnostics.concat(check_output_location_collisions(program)) if enabled?("E005")
      diagnostics.concat(check_duplicate_names_within_a_stage(program)) if enabled?("E006")
      diagnostics.concat(check_reserved_gl_prefix(program)) if enabled?("E007")
      Result.new(diagnostics)
    end

    private

    # E001/E002/W001はvertexのoutとfragmentのin(Reflection上はどちらも
    # `attributes`/`outputs`という同じ構造体で表現される)を名前で突き合わせる。
    # 3つとも両ステージが揃っていないと意味を持たないため、片方でも欠けていれば
    # 何も検出しない(§8.3 E002のスキップ条件と同じ扱いをW001/E001にも広げる)。
    #
    # アンカーはSPEC.md §8.3の規則通り: fragment側に該当宣言があればfragment、
    # 無ければvertexを指す。E001は必ず両側に宣言があるのでfragment固定、
    # E002はfragment側にのみ、W001はvertex側にのみ宣言がある。
    def check_out_in_correspondence(program)
      vertex = program.sources[:vertex]
      fragment = program.sources[:fragment]
      return [] unless vertex && fragment

      vertex_out = index_by_name(vertex.reflection.outputs)
      fragment_in = index_by_name(fragment.reflection.attributes)

      diagnostics = []
      diagnostics.concat(check_type_mismatch(program, fragment, vertex_out, fragment_in)) if enabled?("E001")
      diagnostics.concat(check_missing_vertex_out(program, fragment, vertex_out, fragment_in)) if enabled?("E002")
      diagnostics.concat(check_missing_fragment_in(program, vertex, vertex_out, fragment_in)) if enabled?("W001")
      diagnostics
    end

    def check_type_mismatch(program, fragment, vertex_out, fragment_in)
      (vertex_out.keys & fragment_in.keys).filter_map do |name|
        v, f = vertex_out[name], fragment_in[name]
        next if v.type == f.type

        message = "\"#{name}\": vertex out is #{v.type}, fragment in is #{f.type}"
        build_diagnostic(program, :fragment, fragment, "E001", name, f.output_line, message)
      end
    end

    def check_missing_vertex_out(program, fragment, vertex_out, fragment_in)
      (fragment_in.keys - vertex_out.keys).map do |name|
        f = fragment_in[name]
        message = "\"#{name}\": fragment in has no matching vertex out"
        build_diagnostic(program, :fragment, fragment, "E002", name, f.output_line, message, severity: :warning)
      end
    end

    def check_missing_fragment_in(program, vertex, vertex_out, fragment_in)
      (vertex_out.keys - fragment_in.keys).map do |name|
        v = vertex_out[name]
        message = "\"#{name}\": vertex out has no matching fragment in"
        build_diagnostic(program, :vertex, vertex, "W001", name, v.output_line, message, severity: :warning)
      end
    end

    # 既存のManifest#merge_uniforms/#merge_uniform_blocksがStageMismatchErrorを
    # 投げる条件を、マージ前に同じロジックで検出する(§8.4「E003の扱い」)。
    # 名前が両ステージに存在する場合のみ比較する(片方だけならエラーにならない、
    # という既存のManifestの挙動に合わせる)。
    def check_cross_stage_uniform_mismatch(program)
      vertex = program.sources[:vertex]
      fragment = program.sources[:fragment]
      return [] unless vertex && fragment

      check_uniform_type_mismatch(program, vertex, fragment) +
        check_uniform_block_mismatch(program, vertex, fragment)
    end

    def check_uniform_type_mismatch(program, vertex, fragment)
      vertex_uniforms = index_by_name(vertex.reflection.uniforms)
      fragment_uniforms = index_by_name(fragment.reflection.uniforms)

      (vertex_uniforms.keys & fragment_uniforms.keys).filter_map do |name|
        v, f = vertex_uniforms[name], fragment_uniforms[name]
        next if v.type == f.type

        message = "uniform \"#{name}\" is #{v.type} in vertex but #{f.type} in fragment"
        build_diagnostic(program, :fragment, fragment, "E003", name, f.output_line, message)
      end
    end

    def check_uniform_block_mismatch(program, vertex, fragment)
      vertex_blocks = index_by_name(vertex.reflection.uniform_blocks)
      fragment_blocks = index_by_name(fragment.reflection.uniform_blocks)

      (vertex_blocks.keys & fragment_blocks.keys).filter_map do |name|
        v, f = vertex_blocks[name], fragment_blocks[name]
        next if v.layout == f.layout && v.binding == f.binding

        message = "uniform block \"#{name}\" differs between vertex and fragment " \
          "(layout: #{v.layout} vs #{f.layout}, binding: #{v.binding.inspect} vs #{f.binding.inspect})"
        build_diagnostic(program, :fragment, fragment, "E003", name, f.output_line, message)
      end
    end

    def index_by_name(entries)
      entries.each_with_object({}) { |entry, hash| hash[entry.name] = entry }
    end

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

    def build_diagnostic(program, stage, source, code, name, output_line, message, severity: :error)
      file, line = source.source_map&.resolve(output_line) || [nil, nil]
      Diagnostic.new(
        severity: severity,
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
