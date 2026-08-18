# frozen_string_literal: true

require "test_helper"

class SourceMapTest < Minitest::Test
  def setup
    @map = Glslkit::SourceMap.new
    @entry = @map.index_for("entry.frag")
    @included = @map.index_for("common/math.glsl")
  end

  def test_index_for_is_stable_and_ordered_by_first_registration
    assert_equal 0, @entry
    assert_equal 1, @included
    assert_equal 0, @map.index_for("entry.frag") # re-registering the same path returns the same index
    assert_equal ["entry.frag", "common/math.glsl"], @map.files
  end

  def test_resolve_within_a_single_segment
    @map.add_segment(output_line: 5, file_index: @entry, source_line: 2)

    assert_equal ["entry.frag", 2], @map.resolve(5)
    assert_equal ["entry.frag", 3], @map.resolve(6)
    assert_equal ["entry.frag", 7], @map.resolve(10)
  end

  def test_resolve_across_multiple_segments
    @map.add_segment(output_line: 1, file_index: @entry, source_line: 1)
    @map.add_segment(output_line: 3, file_index: @included, source_line: 10)
    @map.add_segment(output_line: 5, file_index: @entry, source_line: 4)

    assert_equal ["entry.frag", 1], @map.resolve(1)
    assert_equal ["entry.frag", 2], @map.resolve(2)
    assert_equal ["common/math.glsl", 10], @map.resolve(3)
    assert_equal ["common/math.glsl", 11], @map.resolve(4)
    assert_equal ["entry.frag", 4], @map.resolve(5)
    assert_equal ["entry.frag", 5], @map.resolve(6)
  end

  def test_resolve_returns_nil_before_the_first_segment
    @map.add_segment(output_line: 3, file_index: @entry, source_line: 1)

    refute @map.resolve(1)
    refute @map.resolve(2)
    refute @map.resolve(0)
    refute @map.resolve(-1)
  end

  def test_resolve_returns_nil_when_no_segments_are_recorded
    refute @map.resolve(1)
  end
end
