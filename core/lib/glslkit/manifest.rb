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
    def group_by_name(stage_entries)
      grouped = {}
      stage_entries.each do |stage, entries|
        entries.each { |entry| (grouped[entry.name] ||= {})[stage] = entry }
      end
      grouped
    end
  end
end
