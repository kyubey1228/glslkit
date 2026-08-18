# frozen_string_literal: true

require "test_helper"

class DiagnosticTest < Minitest::Test
  def build(overrides = {})
    Glslkit::Diagnostic.new(
      {severity: :error, code: "E001", message: "type mismatch", program: "pbr", stage: :fragment,
       name: "v_uv", file: nil, line: nil}.merge(overrides)
    )
  end

  def test_to_s_with_file_and_line
    diagnostic = build(file: "common/math.glsl", line: 12)

    assert_equal "[E001] common/math.glsl:12: type mismatch", diagnostic.to_s
  end

  def test_to_s_without_file_falls_back_to_program_and_stage
    diagnostic = build(file: nil, line: nil)

    assert_equal "[E001] pbr(fragment): type mismatch", diagnostic.to_s
  end

  def test_to_s_without_file_or_stage
    diagnostic = build(file: nil, line: nil, stage: nil)

    assert_equal "[E001] pbr: type mismatch", diagnostic.to_s
  end

  def test_error_and_warning_predicates
    error = build(severity: :error)
    warning = build(severity: :warning, code: "W001")

    assert error.error?
    refute error.warning?
    assert warning.warning?
    refute warning.error?
  end
end
