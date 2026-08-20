# frozen_string_literal: true

require "test_helper"
require_relative "../sample/error_panel"

# M10d: neon-error.htmlの表示ロジック。M10a修正2で確認した
# 「resolveがnilを返す場合、file/lineがnilに落ちてraw_logは保たれる」経路が
# 表示側で壊れない(nilを前提にしてNoMethodErrorにならない)ことを固定する。
class ErrorPanelTest < Minitest::Test
  def test_describes_a_resolved_compile_error
    error = Glslkit::WebGL::CompileError.new(
      stage: :fragment, raw_log: "ERROR: 0:5: 'return' : syntax error",
      file: "common/sdf.glsl", line: 5, detail: "'return' : syntax error"
    )

    described = NeonErrorPanel.describe(error)

    assert_equal "fragment", described[:stage]
    assert_equal "common/sdf.glsl", described[:file]
    assert described[:resolved]
    assert_equal "5", described[:line]
    assert_equal "common/sdf.glsl:5: 'return' : syntax error", described[:message]
    assert_equal "ERROR: 0:5: 'return' : syntax error", described[:raw_log]
  end

  def test_describes_an_unresolved_compile_error_without_raising
    error = Glslkit::WebGL::CompileError.new(
      stage: :fragment, raw_log: "driver said no", file: nil, line: nil, detail: nil
    )

    described = NeonErrorPanel.describe(error)

    refute described[:resolved]
    assert_equal NeonErrorPanel::UNRESOLVED_FILE, described[:file]
    assert_equal NeonErrorPanel::UNRESOLVED_LINE, described[:line]
    assert_equal "driver said no", described[:message]
    assert_equal "driver said no", described[:raw_log]
  end
end
