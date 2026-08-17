# frozen_string_literal: true

require "test_helper"

class MinifierTest < Minitest::Test
  SAMPLE = <<~GLSL
    #version 300 es
    // a line comment
    /* a block
       comment */
    precision   mediump   float;

    layout(location = 0) in vec3 a_position;
    uniform mat4   u_model_view; // trailing comment
    uniform vec4 u_lights[8];
    layout(std140, binding = 0) uniform Camera {
      mat4 view;
    };
    out vec4 fragColor;

    void main() {
      /* local */
      vec3 x = a_position;
      fragColor = vec4(x, 1.0);
    }
  GLSL

  def test_line_comments_are_removed
    minified = Glslkit::Minifier.minify("uniform vec3 u_color; // a comment\n")

    refute_includes minified, "//"
    refute_includes minified, "a comment"
  end

  def test_single_line_block_comments_are_removed_without_gluing_tokens
    minified = Glslkit::Minifier.minify("vec3/* x */foo;\n")

    refute_includes minified, "/*"
    refute_includes minified, "vec3foo"
  end

  def test_multi_line_block_comments_are_removed_and_preserve_line_count
    code = "uniform vec3 u_a;\n/* line1\nline2\nline3 */\nuniform vec3 u_b;\n"

    minified = Glslkit::Minifier.minify(code)

    assert_equal code.lines.size, minified.lines.size
    refute_includes minified, "line1"
  end

  def test_leading_and_trailing_whitespace_is_stripped
    minified = Glslkit::Minifier.minify("   uniform vec3 u_color;   \n")

    assert_equal "uniform vec3 u_color;\n", minified
  end

  def test_internal_whitespace_runs_are_collapsed
    minified = Glslkit::Minifier.minify("uniform   mat4    u_model_view;\n")

    assert_equal "uniform mat4 u_model_view;\n", minified
  end

  def test_line_count_is_preserved_so_line_directives_stay_correct
    minified = Glslkit::Minifier.minify(SAMPLE)

    assert_equal SAMPLE.lines.size, minified.lines.size
  end

  def test_reflection_is_unchanged_by_minification
    original = Glslkit::Reflection.new(SAMPLE)
    minified = Glslkit::Reflection.new(Glslkit::Minifier.minify(SAMPLE))

    assert_equal original.attributes, minified.attributes
    assert_equal original.uniforms, minified.uniforms
    assert_equal original.uniform_blocks, minified.uniform_blocks
    assert_equal original.outputs, minified.outputs
  end

  def test_line_directives_left_by_the_preprocessor_survive_minification
    resolver = Glslkit::Resolvers::Hash.new("a.frag" => SAMPLE)
    source = Glslkit::Preprocessor.new(resolver: resolver).process("a.frag")

    minified_code = Glslkit::Minifier.minify(source.code)
    minified_reflection = Glslkit::Reflection.new(minified_code)

    assert_includes minified_code, "#line"
    assert_equal source.reflection.uniforms, minified_reflection.uniforms
    assert_equal source.reflection.attributes, minified_reflection.attributes
  end
end
