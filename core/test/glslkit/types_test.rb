# frozen_string_literal: true

require "test_helper"

class TypesTest < Minitest::Test
  EXPECTATIONS = {
    "float" => {setter: "uniform1fv", matrix: false, sampler: false, components: 1},
    "vec2" => {setter: "uniform2fv", matrix: false, sampler: false, components: 2},
    "vec3" => {setter: "uniform3fv", matrix: false, sampler: false, components: 3},
    "vec4" => {setter: "uniform4fv", matrix: false, sampler: false, components: 4},
    "int" => {setter: "uniform1iv", matrix: false, sampler: false, components: 1},
    "bool" => {setter: "uniform1iv", matrix: false, sampler: false, components: 1},
    "ivec2" => {setter: "uniform2iv", matrix: false, sampler: false, components: 2},
    "bvec2" => {setter: "uniform2iv", matrix: false, sampler: false, components: 2},
    "ivec3" => {setter: "uniform3iv", matrix: false, sampler: false, components: 3},
    "bvec3" => {setter: "uniform3iv", matrix: false, sampler: false, components: 3},
    "ivec4" => {setter: "uniform4iv", matrix: false, sampler: false, components: 4},
    "bvec4" => {setter: "uniform4iv", matrix: false, sampler: false, components: 4},
    "uint" => {setter: "uniform1uiv", matrix: false, sampler: false, components: 1},
    "uvec2" => {setter: "uniform2uiv", matrix: false, sampler: false, components: 2},
    "uvec3" => {setter: "uniform3uiv", matrix: false, sampler: false, components: 3},
    "uvec4" => {setter: "uniform4uiv", matrix: false, sampler: false, components: 4},
    "mat2" => {setter: "uniformMatrix2fv", matrix: true, sampler: false, components: 4},
    "mat3" => {setter: "uniformMatrix3fv", matrix: true, sampler: false, components: 9},
    "mat4" => {setter: "uniformMatrix4fv", matrix: true, sampler: false, components: 16},
    "mat2x3" => {setter: "uniformMatrix2x3fv", matrix: true, sampler: false, components: 6},
    "mat2x4" => {setter: "uniformMatrix2x4fv", matrix: true, sampler: false, components: 8},
    "mat3x2" => {setter: "uniformMatrix3x2fv", matrix: true, sampler: false, components: 6},
    "mat3x4" => {setter: "uniformMatrix3x4fv", matrix: true, sampler: false, components: 12},
    "mat4x2" => {setter: "uniformMatrix4x2fv", matrix: true, sampler: false, components: 8},
    "mat4x3" => {setter: "uniformMatrix4x3fv", matrix: true, sampler: false, components: 12},
    "sampler2D" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "sampler3D" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "samplerCube" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "sampler2DArray" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "isampler2D" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "isampler3D" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "isamplerCube" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "isampler2DArray" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "usampler2D" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "usampler3D" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "usamplerCube" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "usampler2DArray" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "sampler2DShadow" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "samplerCubeShadow" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1},
    "sampler2DArrayShadow" => {setter: "uniform1iv", matrix: false, sampler: true, components: 1}
  }.freeze

  EXPECTATIONS.each do |type, expected|
    define_method("test_#{type}_maps_to_#{expected[:setter]}") do
      assert_equal expected[:setter], Glslkit::Types.setter_for(type)
      assert_equal expected[:matrix], Glslkit::Types.matrix?(type)
      assert_equal expected[:sampler], Glslkit::Types.sampler?(type)
      assert_equal expected[:components], Glslkit::Types.components_for(type)
    end
  end

  def test_covers_every_entry_in_the_table
    assert_equal Glslkit::Types::ENTRIES.keys.sort, EXPECTATIONS.keys.sort
  end

  def test_unknown_type_raises
    error = assert_raises(Glslkit::UnknownTypeError) { Glslkit::Types.setter_for("vec5") }
    assert_match(/vec5/, error.message)
  end
end
