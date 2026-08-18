# frozen_string_literal: true

require "test_helper"
require "json"
require "json_schemer"

class SourceMapTest < Minitest::Test
  SCHEMA_PATH = File.expand_path("../../../spec/schema/source-map-v1.json", __dir__)

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

  def test_to_h_round_trips_through_from_h
    @map.add_segment(output_line: 1, file_index: @entry, source_line: 1)
    @map.add_segment(output_line: 3, file_index: @included, source_line: 10)
    @map.add_segment(output_line: 5, file_index: @entry, source_line: 4)

    restored = Glslkit::SourceMap.from_h(@map.to_h)

    (1..6).each do |output_line|
      assert_equal @map.resolve(output_line), restored.resolve(output_line)
    end
  end

  def test_to_h_matches_the_schema
    @map.add_segment(output_line: 1, file_index: @entry, source_line: 1)
    @map.add_segment(output_line: 3, file_index: @included, source_line: 10)

    schema = JSONSchemer.schema(JSON.parse(File.read(SCHEMA_PATH)))
    doc = JSON.parse(JSON.generate(@map.to_h))
    assert schema.valid?(doc), schema.validate(doc).to_a.inspect
  end

  def test_to_h_shape
    @map.add_segment(output_line: 5, file_index: @entry, source_line: 2)

    assert_equal(
      {"version" => 1, "files" => ["entry.frag", "common/math.glsl"], "segments" => [[5, 0, 2]]},
      @map.to_h
    )
  end

  def test_to_h_sorts_segments_by_output_line_even_if_added_out_of_order
    @map.add_segment(output_line: 5, file_index: @entry, source_line: 4)
    @map.add_segment(output_line: 1, file_index: @entry, source_line: 1)

    assert_equal [[1, 0, 1], [5, 0, 4]], @map.to_h["segments"]
  end

  def test_from_h_rejects_an_unsupported_version
    hash = {"version" => 2, "files" => [], "segments" => []}

    assert_raises(Glslkit::SourceMap::UnsupportedVersionError) { Glslkit::SourceMap.from_h(hash) }
  end

  # from_h は segments が output_line 昇順であることを前提にしてよい(未ソートの
  # 挙動は保証しない)。ただし「保証しない」を野放しにせず、現状どう壊れるかを
  # 固定しておく: bsearch_index は昇順を前提にした二分探索なので、順序が
  # 違反されると探索が正しい区間を素通りし、間違った(が決定的な)結果を返す。
  # ここでは output_line=10 の区間が配列の先頭にあるせいで見つからず、
  # 1つ前の区間(output_line=5)がそのまま使われてしまう例を固定する。
  def test_from_h_with_unsorted_segments_has_pinned_but_incorrect_behavior
    unsorted = Glslkit::SourceMap.from_h(
      "version" => 1,
      "files" => ["a.frag"],
      "segments" => [[10, 0, 100], [1, 0, 1], [5, 0, 50]]
    )

    # 正しく並んでいれば output_line=10 は source_line=100 に解決されるはずだが、
    # 未ソート入力では1つ前の区間(output_line=5, source_line=50)が誤って
    # 使われ続ける。これは「正しい」ではなく「現状こうなる」の記録。
    assert_equal ["a.frag", 55], unsorted.resolve(10)
    assert_equal ["a.frag", 54], unsorted.resolve(9)
  end
end
