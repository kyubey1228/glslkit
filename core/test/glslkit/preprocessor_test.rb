# frozen_string_literal: true

require "test_helper"

class PreprocessorTest < Minitest::Test
  FIXTURES = File.expand_path("../fixtures/shaders", __dir__)

  def process(scenario, entry)
    resolver = Glslkit::Resolvers::FileSystem.new(load_paths: [File.join(FIXTURES, scenario)])
    Glslkit::Preprocessor.new(resolver: resolver).process(entry)
  end

  def test_simple_include_is_flattened_in
    source = process("simple", "entry.frag")

    assert_includes source.code, "float included_value() { return 1.0; }"
    assert_equal ["entry.frag", "included.glsl"], source.source_map.files
  end

  def test_nested_include_is_flattened_in
    source = process("nested", "entry.frag")

    assert_includes source.code, "float c_value() { return 3.0; }"
    assert_equal ["entry.frag", "b.glsl", "c.glsl"], source.source_map.files
  end

  def test_relative_path_resolution
    source = process("relative", "entry.frag")

    assert_includes source.code, "float bar_value() { return 42.0; }"
  end

  def test_angle_brackets_do_not_search_relative_to_the_includer
    source = process("angle_bracket", "sub/entry.frag")

    assert_includes source.code, "return 1.0"
    refute_includes source.code, "return 999.0"
  end

  def test_circular_include_raises_with_chain_in_message
    error = assert_raises(Glslkit::CircularIncludeError) { process("circular", "a.glsl") }

    assert_equal "a.glsl -> b.glsl -> a.glsl", error.message
  end

  def test_pragma_once_skips_the_second_expansion
    source = process("pragma_once", "entry.frag")

    assert_equal 1, source.code.scan("once_value").size
  end

  def test_duplicate_include_without_pragma_once_expands_every_time
    source = process("duplicate_include", "entry.frag")

    assert_equal 2, source.code.scan("dup_value").size
  end

  def test_version_scattered_across_files_appears_once_on_line_one
    source = process("version_single", "entry.frag")

    lines = source.code.lines
    assert_equal "#version 300 es\n", lines.first
    assert_equal 1, source.code.scan("#version").size
  end

  def test_conflicting_versions_raise
    assert_raises(Glslkit::VersionConflictError) { process("version_conflict", "entry.frag") }
  end

  def test_missing_include_raises
    assert_raises(Glslkit::IncludeNotFound) { process("missing_include", "entry.frag") }
  end

  def test_path_traversal_raises
    assert_raises(Glslkit::PathTraversalError) { process("path_traversal", "entry.frag") }
  end

  def test_line_directives_match_the_golden_file
    source = process("line_directives", "entry.frag")
    expected = File.read(File.join(FIXTURES, "line_directives", "expected_output.glsl"))

    assert_equal expected, source.code
  end

  def test_line_directives_can_be_suppressed
    resolver = Glslkit::Resolvers::FileSystem.new(load_paths: [File.join(FIXTURES, "line_directives")])
    source = Glslkit::Preprocessor.new(resolver: resolver, line_directives: false).process("entry.frag")

    refute_includes source.code, "#line"
  end
end
