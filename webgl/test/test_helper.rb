# frozen_string_literal: true

require "minitest/autorun"
require "glslkit/webgl"

class FakeGL
  CONSTANTS = {
    VERTEX_SHADER: 1, FRAGMENT_SHADER: 2, COMPILE_STATUS: 3, LINK_STATUS: 4,
    TRIANGLES: 5, ARRAY_BUFFER: 6, ELEMENT_ARRAY_BUFFER: 7, STATIC_DRAW: 8,
    FLOAT: 9, UNSIGNED_SHORT: 10, UNSIGNED_INT: 11, NO_ERROR: 0,
    TEXTURE_2D: 12, RGBA: 13, UNSIGNED_BYTE: 14, TEXTURE_MIN_FILTER: 15,
    TEXTURE_MAG_FILTER: 16, NEAREST: 17, TEXTURE0: 100, DEPTH_TEST: 18,
    COLOR_BUFFER_BIT: 1, DEPTH_BUFFER_BIT: 2
  }.freeze

  attr_reader :calls
  attr_accessor :shader_ok, :program_ok, :shader_log, :program_log, :uniform_locations,
    :attribute_locations

  def initialize
    @calls = []
    @shader_ok = true
    @program_ok = true
    @shader_log = ""
    @program_log = ""
    @uniform_locations = {}
    @attribute_locations = {}
    @serial = 0
  end

  def [](name)
    CONSTANTS.fetch(name)
  end

  def call(name, *args)
    @calls << [name, *args]
    case name
    when :createShader, :createProgram, :createVertexArray, :createBuffer, :createTexture
      @serial += 1
      JS::Object.new(@serial)
    when :getShaderParameter
      @shader_ok ? JS::True : JS::Object.new(false)
    when :getProgramParameter
      @program_ok ? JS::True : JS::Object.new(false)
    when :getShaderInfoLog then JS::Object.new(@shader_log)
    when :getProgramInfoLog then JS::Object.new(@program_log)
    when :getUniformLocation
      @uniform_locations.fetch(args[1], JS::Object.new("loc:#{args[1]}"))
    when :getAttribLocation
      JS::Object.new(@attribute_locations.fetch(args[1], -1))
    when :getError then JS::Object.new(0)
    end
  end
end

module WebglFixtures
  def manifest_program(uniforms: [], attributes: [])
    {
      "digest" => "0" * 64,
      "stages" => {},
      "attributes" => attributes,
      "uniforms" => uniforms,
      "uniform_blocks" => [],
      "outputs" => []
    }
  end

  def uniform(name: "u_color", setter: "uniform4fv", matrix: false, count: 4)
    {
      "name" => name,
      "type" => "vec4",
      "array_size" => 1,
      "setter" => setter,
      "matrix" => matrix,
      "sampler" => false,
      "components" => count,
      "element_count" => count,
      "stages" => ["fragment"]
    }
  end
end
