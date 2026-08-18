# frozen_string_literal: true

require "test_helper"

class ProgramTest < Minitest::Test
  def test_accepts_both_stages
    program = Glslkit::Program.new(name: "pbr", sources: {vertex: :v, fragment: :f})

    assert_equal "pbr", program.name
    assert_equal :v, program.vertex
    assert_equal :f, program.fragment
  end

  def test_accepts_a_single_stage
    program = Glslkit::Program.new(name: "pbr", sources: {fragment: :f})

    assert_nil program.vertex
    assert_equal :f, program.fragment
  end

  def test_rejects_empty_sources
    assert_raises(ArgumentError) { Glslkit::Program.new(name: "pbr", sources: {}) }
  end

  def test_rejects_unknown_stage_keys
    assert_raises(ArgumentError) { Glslkit::Program.new(name: "pbr", sources: {geometry: :g}) }
  end
end
