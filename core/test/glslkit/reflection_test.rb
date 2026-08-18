# frozen_string_literal: true

require "test_helper"

class ReflectionTest < Minitest::Test
  def test_every_type_in_the_table_is_resolved_correctly_through_a_uniform_declaration
    code = Glslkit::Types::ENTRIES.keys.each_with_index.map { |type, i| "uniform #{type} u_#{i};" }.join("\n")
    reflection = Glslkit::Reflection.new(code)

    assert_equal Glslkit::Types::ENTRIES.size, reflection.uniforms.size

    reflection.uniforms.each do |uniform|
      expected = Glslkit::Types.entry_for(uniform.type)
      assert_equal expected[:setter], uniform.setter
      assert_equal expected[:matrix], uniform.matrix
      assert_equal expected[:sampler], uniform.sampler
      assert_equal 1, uniform.array_size
    end
  end

  def test_local_variables_inside_a_function_body_are_not_extracted
    code = <<~GLSL
      void main() {
        uniform vec3 fake_uniform;
        in vec2 fake_attribute;
        out vec4 fake_output;
      }
      uniform vec3 real_uniform;
    GLSL

    reflection = Glslkit::Reflection.new(code)

    assert_equal ["real_uniform"], reflection.uniforms.map(&:name)
    assert_empty reflection.attributes
    assert_empty reflection.outputs
  end

  def test_attribute_with_explicit_location
    reflection = Glslkit::Reflection.new("layout(location = 0) in vec3 a_position;")

    attribute = reflection.attributes.first
    assert_equal "a_position", attribute.name
    assert_equal "vec3", attribute.type
    assert_equal 0, attribute.location
    assert_equal 1, attribute.array_size
  end

  def test_attribute_without_explicit_location_is_null
    reflection = Glslkit::Reflection.new("in vec2 a_uv;")

    attribute = reflection.attributes.first
    assert_equal "a_uv", attribute.name
    assert_nil attribute.location
  end

  def test_array_uniform
    reflection = Glslkit::Reflection.new("uniform vec4 u_lights[8];")

    uniform = reflection.uniforms.first
    assert_equal "u_lights", uniform.name
    assert_equal 8, uniform.array_size
  end

  def test_multiple_render_targets
    code = <<~GLSL
      out vec4 fragColor;
      layout(location = 0) out vec4 gAlbedo;
      layout(location = 1) out vec3 gNormal;
    GLSL

    reflection = Glslkit::Reflection.new(code)

    assert_equal 3, reflection.outputs.size
    assert_equal [nil, 0, 1], reflection.outputs.map(&:location)
    assert_equal %w[fragColor gAlbedo gNormal], reflection.outputs.map(&:name)
  end

  def test_uniform_inside_a_comment_is_not_extracted
    code = <<~GLSL
      // uniform vec3 fake_one;
      /* uniform vec3 fake_two; */
      uniform vec3 real_uniform;
    GLSL

    reflection = Glslkit::Reflection.new(code)

    assert_equal ["real_uniform"], reflection.uniforms.map(&:name)
  end

  def test_declaration_spanning_multiple_lines
    code = "uniform\n  mat4\n  u_model_view;\n"

    reflection = Glslkit::Reflection.new(code)

    uniform = reflection.uniforms.first
    assert_equal "u_model_view", uniform.name
    assert_equal "mat4", uniform.type
    assert_equal "uniformMatrix4fv", uniform.setter
  end

  def test_uniform_block_with_explicit_layout_and_binding
    code = <<~GLSL
      layout(std140, binding = 0) uniform Camera {
        mat4 view;
        mat4 projection;
      };
    GLSL

    reflection = Glslkit::Reflection.new(code)

    block = reflection.uniform_blocks.first
    assert_equal "Camera", block.name
    assert_equal "std140", block.layout
    assert_equal 0, block.binding
    assert_empty reflection.uniforms
  end

  def test_uniform_block_without_layout_qualifier_defaults_to_shared
    code = <<~GLSL
      uniform Camera {
        mat4 view;
      };
    GLSL

    reflection = Glslkit::Reflection.new(code)

    block = reflection.uniform_blocks.first
    assert_equal "shared", block.layout
    assert_nil block.binding
  end

  def test_struct_and_const_declarations_are_ignored
    code = <<~GLSL
      struct Light {
        vec3 position;
        float intensity;
      };
      const float PI = 3.14159;
      uniform vec3 u_color;
    GLSL

    reflection = Glslkit::Reflection.new(code)

    assert_equal ["u_color"], reflection.uniforms.map(&:name)
    assert_empty reflection.uniform_blocks
  end

  def test_unknown_type_raises
    assert_raises(Glslkit::UnknownTypeError) { Glslkit::Reflection.new("uniform vec5 u_bad;") }
  end

  def test_line_directives_left_by_the_preprocessor_do_not_break_parsing
    code = "#line 3 0\nuniform vec3 u_color;\n#line 7 1\nin vec2 a_uv;\n"

    reflection = Glslkit::Reflection.new(code)

    assert_equal ["u_color"], reflection.uniforms.map(&:name)
    assert_equal ["a_uv"], reflection.attributes.map(&:name)
  end

  def test_output_line_points_to_the_declaration_itself
    code = "uniform vec3 u_a;\nuniform vec3 u_b;\n"

    reflection = Glslkit::Reflection.new(code)

    assert_equal [1, 2], reflection.uniforms.map(&:output_line)
  end

  def test_output_line_skips_past_a_preceding_multi_line_comment
    code = <<~GLSL
      /* line1
         line2
         line3 */
      uniform vec3 u_color;
    GLSL

    reflection = Glslkit::Reflection.new(code)

    assert_equal 4, reflection.uniforms.first.output_line
  end

  def test_output_line_skips_past_preceding_blank_lines
    code = "\n\n\nuniform vec3 u_color;\n"

    reflection = Glslkit::Reflection.new(code)

    assert_equal 4, reflection.uniforms.first.output_line
  end

  def test_output_line_of_a_declaration_spanning_multiple_lines_is_its_first_line
    code = "uniform\n  mat4\n  u_model_view;\n"

    reflection = Glslkit::Reflection.new(code)

    assert_equal 1, reflection.uniforms.first.output_line
  end

  def test_output_line_after_a_single_line_comment_on_its_own_line
    code = "// a comment\nuniform vec3 u_color;\n"

    reflection = Glslkit::Reflection.new(code)

    assert_equal 2, reflection.uniforms.first.output_line
  end

  def test_strip_noise_preserves_the_total_line_count
    code = <<~GLSL
      #version 300 es
      // a comment
      /* a
         multi-line
         comment */
      uniform vec3 u_color;
    GLSL

    stripped = Glslkit::Reflection.new(code).send(:strip_noise, code)

    assert_equal code.lines.size, stripped.lines.size
  end
end
