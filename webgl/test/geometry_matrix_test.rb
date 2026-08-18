# frozen_string_literal: true

require "test_helper"

class WebglGeometryMatrixTest < Minitest::Test
  ProgramStub = Struct.new(:attribute_locations)

  def test_static_geometry_uses_typed_array_from_and_configures_vao
    gl = FakeGL.new
    program = ProgramStub.new({a_position: 0})
    geometry = Glslkit::WebGL::Geometry.new(gl, program,
      attributes: {a_position: {data: [0, 0, 1, 0, 0, 1], components: 2}},
      indices: [0, 1, 2])

    assert geometry.indexed
    assert_equal 3, geometry.count
    names = gl.calls.map(&:first)
    assert_includes names, :vertexAttribPointer
    assert_includes names, :bufferData
  end

  def test_rotation_z_updates_existing_buffer
    out = Array.new(16)

    assert_same out, Glslkit::WebGL::Matrix.rotation_z!(out, Math::PI / 2)
    assert_in_delta 0.0, out[0], 1e-12
    assert_in_delta 1.0, out[1], 1e-12
    assert_in_delta(-1.0, out[4], 1e-12)
    assert_in_delta 1.0, out[15], 1e-12
  end

  def test_perspective_updates_existing_buffer
    out = Array.new(16)

    assert_same out, Glslkit::WebGL::Matrix.perspective!(out, Math::PI / 2, 2.0, 0.1, 100.0)
    assert_in_delta 0.5, out[0], 1e-12
    assert_in_delta 1.0, out[5], 1e-12
    assert_equal(-1.0, out[11])
  end

  def test_multiply_updates_existing_buffer
    left = Array.new(16)
    right = Array.new(16)
    out = Array.new(16)
    Glslkit::WebGL::Matrix.translation!(left, 1, 2, 3)
    Glslkit::WebGL::Matrix.rotation_y!(right, 0)

    assert_same out, Glslkit::WebGL::Matrix.multiply!(out, left, right)
    assert_equal [1, 2, 3], [out[12], out[13], out[14]]
  end
end
