# frozen_string_literal: true

require "json"
require "digest"
require_relative "errors"

module Glslkit
  # プログラムごとのvertex+fragment Sourceペアから reflection-v1.json の
  # マニフェスト(spec/schema/reflection-v1.json)を組み立てる。各stageの
  # `url`は呼び出し側から渡される不透明な文字列(例: Propshaftの
  # フィンガープリント付きアセットパス)である — glslkit自身のdigestとは
  # 無関係で、digestから導出することはなく、渡された値をそのまま格納する
  # だけである。
  class Manifest
    # Glslkit::Program (§8.3) の配列からマニフェストのHashを直接組み立てる。
    # Validatorと入力を共有できるようにする入口で、内部的には
    # add_program に委譲するだけ(既存のマージロジックには手を入れない)。
    #
    # vertex/fragmentが両方揃っていないProgramは(共有partial等の可能性が
    # あるため)黙ってスキップする — SPEC.md §2.4/§3の「プログラムは
    # 両ステージ必須」という決定と、ManifestBuilder(rails側)が既に
    # 行っているのと同じ扱い。
    #
    # 検証(Validator)は必ずこれより先に呼ぶこと(§8.6)。ここは今まで通り
    # StageMismatchErrorを投げる経路のままなので、検証を経ていない入力を
    # 渡すと診断を得る前に例外で落ちる。
    def self.build(programs:, urls: {}, now: Time.now)
      manifest = new(generated_at: now.utc.iso8601)
      programs.each do |program|
        next unless program.sources.key?(:vertex) && program.sources.key?(:fragment)

        manifest.add_program(
          program.name,
          vertex: stage_input(program, :vertex, urls),
          fragment: stage_input(program, :fragment, urls)
        )
      end
      manifest.to_h
    end

    def self.stage_input(program, stage, urls)
      ext = (stage == :vertex) ? "vert" : "frag"
      {path: "#{program.name}.#{ext}", source: program.sources.fetch(stage), url: urls.dig(program.name, stage)}
    end
    private_class_method :stage_input

    def initialize(generated_at:)
      @generated_at = generated_at
      @programs = {}
    end

    def add_program(name, vertex:, fragment:)
      @programs[name.to_s] = build_program(vertex: vertex, fragment: fragment)
      self
    end

    def to_h
      {
        "schema_version" => 1,
        "generated_at" => @generated_at,
        "programs" => @programs
      }
    end

    def to_json(*args)
      JSON.generate(to_h, *args)
    end

    private

    def build_program(vertex:, fragment:)
      vertex_reflection = vertex.fetch(:source).reflection
      fragment_reflection = fragment.fetch(:source).reflection

      {
        "digest" => program_digest(vertex.fetch(:source).digest, fragment.fetch(:source).digest),
        "stages" => {
          "vertex" => stage_hash(vertex),
          "fragment" => stage_hash(fragment)
        },
        "attributes" => vertex_reflection.attributes.map { |a| attribute_hash(a) },
        "uniforms" => merge_uniforms(vertex_reflection.uniforms, fragment_reflection.uniforms),
        "uniform_blocks" => merge_uniform_blocks(vertex_reflection.uniform_blocks, fragment_reflection.uniform_blocks),
        "outputs" => fragment_reflection.outputs.map { |o| output_hash(o) }
      }
    end

    def program_digest(vertex_digest, fragment_digest)
      Digest::SHA256.hexdigest("#{vertex_digest}:#{fragment_digest}")
    end

    def stage_hash(stage)
      {"path" => stage.fetch(:path), "digest" => stage.fetch(:source).digest, "url" => stage.fetch(:url)}
    end

    def attribute_hash(attribute)
      {"name" => attribute.name, "type" => attribute.type, "location" => attribute.location,
       "array_size" => attribute.array_size}
    end

    def output_hash(output)
      {"name" => output.name, "type" => output.type, "location" => output.location}
    end

    def merge_uniforms(vertex_uniforms, fragment_uniforms)
      group_by_name(vertex: vertex_uniforms, fragment: fragment_uniforms).map do |name, by_stage|
        first_stage, first_entry = by_stage.first
        by_stage.each do |stage, entry|
          next if entry.type == first_entry.type

          raise StageMismatchError,
            "uniform #{name.inspect} is #{first_entry.type.inspect} in #{first_stage} " \
              "but #{entry.type.inspect} in #{stage}"
        end

        {
          "name" => name,
          "type" => first_entry.type,
          "array_size" => first_entry.array_size,
          "setter" => first_entry.setter,
          "matrix" => first_entry.matrix,
          "sampler" => first_entry.sampler,
          "stages" => by_stage.keys.map(&:to_s)
        }
      end
    end

    def merge_uniform_blocks(vertex_blocks, fragment_blocks)
      group_by_name(vertex: vertex_blocks, fragment: fragment_blocks).map do |name, by_stage|
        first_stage, first_entry = by_stage.first
        by_stage.each do |stage, entry|
          next if entry.layout == first_entry.layout && entry.binding == first_entry.binding

          raise StageMismatchError, "uniform block #{name.inspect} differs between #{first_stage} and #{stage}"
        end

        {
          "name" => name,
          "layout" => first_entry.layout,
          "binding" => first_entry.binding,
          "stages" => by_stage.keys.map(&:to_s)
        }
      end
    end

    # #nameを持つエントリの {vertex: [...], fragment: [...]} を受け取り、
    # 初出順(vertexのエントリが先、fragmentのみの名前はその後)を保った
    # name => {stage => entry} の順序付きHashを返す。
    #
    # 同一ステージのentries内に同名が2件以上あった場合、後のものが前のものを
    # 静かに上書きする(`[stage] = entry`)。これは**入力がValidator(§8.3の
    # E006)で検証済みで、同一ステージ内の重複が存在しないこと**を前提として
    # 許容している。Validatorを経ていない入力でこのメソッドを単体利用すると、
    # 重複が黙って握り潰されるので注意。
    def group_by_name(stage_entries)
      grouped = {}
      stage_entries.each do |stage, entries|
        entries.each { |entry| (grouped[entry.name] ||= {})[stage] = entry }
      end
      grouped
    end
  end
end
