# frozen_string_literal: true

require_relative "errors"

module Glslkit
  # The single source of truth mapping a GLSL type name to its WebGL2 setter.
  # A wasm-side WebGL binding is expected to call Types.setter_for("mat4") etc.
  # rather than re-deriving this table.
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

    ENTRIES = {
      **NON_MATRIX_SETTERS.transform_values { |setter| {setter: setter, matrix: false, sampler: false} },
      **MATRIX_SETTERS.transform_values { |setter| {setter: setter, matrix: true, sampler: false} },
      **SAMPLER_TYPES.to_h { |type| [type, {setter: "uniform1iv", matrix: false, sampler: true}] }
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

    def entry_for(type)
      ENTRIES.fetch(type) { raise UnknownTypeError, "unknown GLSL type: #{type.inspect}" }
    end
  end
end
