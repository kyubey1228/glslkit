# frozen_string_literal: true

require "test_helper"

class TypesTest < Minitest::Test
  EXPECTATIONS = {
    "float" => {setter: "uniform1fv", matrix: false, sampler: false},
    "vec2" => {setter: "uniform2fv", matrix: false, sampler: false},
    "vec3" => {setter: "uniform3fv", matrix: false, sampler: false},
    "vec4" => {setter: "uniform4fv", matrix: false, sampler: false},
    "int" => {setter: "uniform1iv", matrix: false, sampler: false},
    "bool" => {setter: "uniform1iv", matrix: false, sampler: false},
    "ivec2" => {setter: "uniform2iv", matrix: false, sampler: false},
    "bvec2" => {setter: "uniform2iv", matrix: false, sampler: false},
    "ivec3" => {setter: "uniform3iv", matrix: false, sampler: false},
    "bvec3" => {setter: "uniform3iv", matrix: false, sampler: false},
    "ivec4" => {setter: "uniform4iv", matrix: false, sampler: false},
    "bvec4" => {setter: "uniform4iv", matrix: false, sampler: false},
    "uint" => {setter: "uniform1uiv", matrix: false, sampler: false},
    "uvec2" => {setter: "uniform2uiv", matrix: false, sampler: false},
    "uvec3" => {setter: "uniform3uiv", matrix: false, sampler: false},
    "uvec4" => {setter: "uniform4uiv", matrix: false, sampler: false},
    "mat2" => {setter: "uniformMatrix2fv", matrix: true, sampler: false},
    "mat3" => {setter: "uniformMatrix3fv", matrix: true, sampler: false},
    "mat4" => {setter: "uniformMatrix4fv", matrix: true, sampler: false},
    "mat2x3" => {setter: "uniformMatrix2x3fv", matrix: true, sampler: false},
    "mat2x4" => {setter: "uniformMatrix2x4fv", matrix: true, sampler: false},
    "mat3x2" => {setter: "uniformMatrix3x2fv", matrix: true, sampler: false},
    "mat3x4" => {setter: "uniformMatrix3x4fv", matrix: true, sampler: false},
    "mat4x2" => {setter: "uniformMatrix4x2fv", matrix: true, sampler: false},
    "mat4x3" => {setter: "uniformMatrix4x3fv", matrix: true, sampler: false},
    "sampler2D" => {setter: "uniform1iv", matrix: false, sampler: true},
    "sampler3D" => {setter: "uniform1iv", matrix: false, sampler: true},
    "samplerCube" => {setter: "uniform1iv", matrix: false, sampler: true},
    "sampler2DArray" => {setter: "uniform1iv", matrix: false, sampler: true},
    "isampler2D" => {setter: "uniform1iv", matrix: false, sampler: true},
    "isampler3D" => {setter: "uniform1iv", matrix: false, sampler: true},
    "isamplerCube" => {setter: "uniform1iv", matrix: false, sampler: true},
    "isampler2DArray" => {setter: "uniform1iv", matrix: false, sampler: true},
    "usampler2D" => {setter: "uniform1iv", matrix: false, sampler: true},
    "usampler3D" => {setter: "uniform1iv", matrix: false, sampler: true},
    "usamplerCube" => {setter: "uniform1iv", matrix: false, sampler: true},
    "usampler2DArray" => {setter: "uniform1iv", matrix: false, sampler: true},
    "sampler2DShadow" => {setter: "uniform1iv", matrix: false, sampler: true},
    "samplerCubeShadow" => {setter: "uniform1iv", matrix: false, sampler: true},
    "sampler2DArrayShadow" => {setter: "uniform1iv", matrix: false, sampler: true}
  }.freeze

  EXPECTATIONS.each do |type, expected|
    define_method("test_#{type}_maps_to_#{expected[:setter]}") do
      assert_equal expected[:setter], Glslkit::Types.setter_for(type)
      assert_equal expected[:matrix], Glslkit::Types.matrix?(type)
      assert_equal expected[:sampler], Glslkit::Types.sampler?(type)
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
