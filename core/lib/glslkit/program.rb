# frozen_string_literal: true

module Glslkit
  # ValidatorとManifest.buildが共有する薄い値オブジェクト(§8.3)。
  # sourcesはマージ前の Glslkit::Source をそのまま保持する — E006(同一ステージ内の
  # 重複宣言)はマージ後のデータからは検出できないため、生のReflectionへの
  # アクセスが必要になる。
  class Program
    STAGES = %i[vertex fragment].freeze

    attr_reader :name, :sources

    def initialize(name:, sources:)
      unless sources.is_a?(Hash) && !sources.empty? && (sources.keys - STAGES).empty?
        raise ArgumentError, "sources must be a non-empty Hash with only :vertex and/or :fragment keys"
      end

      @name = name
      @sources = sources
    end

    def vertex
      sources[:vertex]
    end

    def fragment
      sources[:fragment]
    end
  end
end
