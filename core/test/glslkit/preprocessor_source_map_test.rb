# frozen_string_literal: true

require "test_helper"

class PreprocessorSourceMapTest < Minitest::Test
  FIXTURES = File.expand_path("../fixtures/shaders/source_map", __dir__)

  def process(line_directives:)
    resolver = Glslkit::Resolvers::FileSystem.new(load_paths: [FIXTURES])
    Glslkit::Preprocessor.new(resolver: resolver, line_directives: line_directives).process("entry.frag")
  end

  def test_resolves_uniforms_back_to_their_original_file_and_line
    source = process(line_directives: true)

    u_scale = source.reflection.uniforms.find { |u| u.name == "u_scale" }
    u_albedo = source.reflection.uniforms.find { |u| u.name == "u_albedo" }

    # u_scale is declared after a single-line comment, a function, a blank
    # line, and a 3-line block comment inside the included file
    assert_equal ["common/math.glsl", 7], source.source_map.resolve(u_scale.output_line)
    assert_equal ["entry.frag", 4], source.source_map.resolve(u_albedo.output_line)
  end

  # The whole point of decoupling position tracking from the text `#line`
  # directives (SPEC.md §8.1): resolve() must agree whether or not the
  # cosmetic #line comments are actually emitted into the output.
  def test_resolution_is_identical_regardless_of_line_directives
    with_lines = process(line_directives: true)
    without_lines = process(line_directives: false)

    resolved = lambda do |source|
      source.reflection.uniforms.to_h do |u|
        [u.name, source.source_map.resolve(u.output_line)]
      end
    end

    assert_includes with_lines.code, "#line"
    refute_includes without_lines.code, "#line"

    assert_equal resolved.call(with_lines), resolved.call(without_lines)
    assert_equal({"u_scale" => ["common/math.glsl", 7], "u_albedo" => ["entry.frag", 4]}, resolved.call(with_lines))
  end
end
