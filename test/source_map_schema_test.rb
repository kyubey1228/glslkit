# frozen_string_literal: true

require "json"
require "json_schemer"
require "minitest/autorun"

class SourceMapSchemaTest < Minitest::Test
  SCHEMA_PATH = File.expand_path("../spec/schema/source-map-v1.json", __dir__)

  def setup
    @schema_json = JSON.parse(File.read(SCHEMA_PATH))
    @schemer = JSONSchemer.schema(@schema_json)
  end

  def test_schema_file_is_valid_json
    assert_kind_of Hash, @schema_json
  end

  def test_schema_itself_conforms_to_draft_2020_12
    assert @schemer.valid_schema?, @schemer.validate_schema.to_a.inspect
  end

  def test_valid_source_map_passes
    assert_valid valid_source_map
  end

  def test_wrong_version_fails
    doc = valid_source_map
    doc["version"] = 2

    refute_valid doc
  end

  def test_missing_files_fails
    doc = valid_source_map
    doc.delete("files")

    refute_valid doc
  end

  def test_segment_with_wrong_arity_fails
    doc = valid_source_map
    doc["segments"] << [1, 0]

    refute_valid doc
  end

  def test_segment_with_negative_file_index_fails
    doc = valid_source_map
    doc["segments"][0][1] = -1

    refute_valid doc
  end

  def test_unknown_top_level_key_fails
    doc = valid_source_map
    doc["unexpected"] = true

    refute_valid doc
  end

  private

  def assert_valid(doc)
    assert @schemer.valid?(doc), @schemer.validate(doc).to_a.inspect
  end

  def refute_valid(doc)
    refute @schemer.valid?(doc)
  end

  def valid_source_map
    JSON.parse(JSON.generate({
      version: 1,
      files: ["entry.frag", "common/math.glsl"],
      segments: [[1, 0, 1], [3, 1, 10], [5, 0, 4]]
    }))
  end
end
