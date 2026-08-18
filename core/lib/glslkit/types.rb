# frozen_string_literal: true

require_relative "errors"

module Glslkit
  # GLSLの型名をWebGL2のsetterに対応付ける唯一の正。wasm側のWebGL
  # バインディングはこのテーブルを自前で再実装するのではなく、
  # Types.setter_for("mat4") 等を呼び出すことを想定している。
  module Types
    NON_MATRIX_SETTERS = {
      "float" => "uniform1fv",
      "vec2" => "uniform2fv",
      "vec3" => "uniform3fv",
      "vec4" => "uniform4fv",
      "int" => "uniform1iv",
      "bool" => "uniform1iv",
      "ivec2" => "uniform2iv",
      "bvec2" => "uniform2iv",
      "ivec3" => "uniform3iv",
      "bvec3" => "uniform3iv",
      "ivec4" => "uniform4iv",
      "bvec4" => "uniform4iv",
      "uint" => "uniform1uiv",
      "uvec2" => "uniform2uiv",
      "uvec3" => "uniform3uiv",
      "uvec4" => "uniform4uiv"
    }.freeze

    MATRIX_SETTERS = {
      "mat2" => "uniformMatrix2fv",
      "mat3" => "uniformMatrix3fv",
      "mat4" => "uniformMatrix4fv",
      "mat2x3" => "uniformMatrix2x3fv",
      "mat2x4" => "uniformMatrix2x4fv",
      "mat3x2" => "uniformMatrix3x2fv",
      "mat3x4" => "uniformMatrix3x4fv",
      "mat4x2" => "uniformMatrix4x2fv",
      "mat4x3" => "uniformMatrix4x3fv"
    }.freeze

    SAMPLER_TYPES = %w[
      sampler2D sampler3D samplerCube sampler2DArray
      isampler2D isampler3D isamplerCube isampler2DArray
      usampler2D usampler3D usamplerCube usampler2DArray
      sampler2DShadow samplerCubeShadow sampler2DArrayShadow
    ].freeze

    # 1要素あたりの成分数(§8.5)。setterに渡す配列の期待長(= components * array_size)の
    # 算出に使う。
    NON_MATRIX_COMPONENTS = {
      "float" => 1, "int" => 1, "bool" => 1, "uint" => 1,
      "vec2" => 2, "ivec2" => 2, "bvec2" => 2, "uvec2" => 2,
      "vec3" => 3, "ivec3" => 3, "bvec3" => 3, "uvec3" => 3,
      "vec4" => 4, "ivec4" => 4, "bvec4" => 4, "uvec4" => 4
    }.freeze

    # matCxR は C列R行の行列(GLSL仕様)。成分数は C * R。
    MATRIX_COMPONENTS = {
      "mat2" => 4, "mat3" => 9, "mat4" => 16,
      "mat2x3" => 6, "mat2x4" => 8,
      "mat3x2" => 6, "mat3x4" => 12,
      "mat4x2" => 8, "mat4x3" => 12
    }.freeze

    ENTRIES = {
      **NON_MATRIX_SETTERS.to_h { |type, setter|
        [type, {setter: setter, matrix: false, sampler: false, components: NON_MATRIX_COMPONENTS.fetch(type)}]
      },
      **MATRIX_SETTERS.to_h { |type, setter|
        [type, {setter: setter, matrix: true, sampler: false, components: MATRIX_COMPONENTS.fetch(type)}]
      },
      **SAMPLER_TYPES.to_h { |type| [type, {setter: "uniform1iv", matrix: false, sampler: true, components: 1}] }
    }.freeze

    module_function

    def setter_for(type)
      entry_for(type)[:setter]
    end

    def matrix?(type)
      entry_for(type)[:matrix]
    end

    def sampler?(type)
      entry_for(type)[:sampler]
    end

    def components_for(type)
      entry_for(type)[:components]
    end

    def entry_for(type)
      ENTRIES.fetch(type) { raise UnknownTypeError, "unknown GLSL type: #{type.inspect}" }
    end
  end
end
