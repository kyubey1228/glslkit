# frozen_string_literal: true

# Glslkit::WebGL::CompileErrorから画面表示用のデータを組み立てる。DOMには
# 一切触れない(webgl/test でDOM無しにユニットテストできるようにするため)。
# `file`/`line`はresolveできなかった場合nilになりうる(M10a修正2)。
# ここで必ずフォールバック文字列に変換し、呼び出し側(neon-error.rb)が
# nilを直接扱わなくて済むようにする。
module NeonErrorPanel
  UNRESOLVED_FILE = "(unresolved — driver did not report a line inside a mapped segment)"
  UNRESOLVED_LINE = "(unresolved)"

  module_function

  def describe(error)
    {
      stage: error.stage.to_s,
      file: error.file || UNRESOLVED_FILE,
      resolved: !error.file.nil?,
      line: error.line ? error.line.to_s : UNRESOLVED_LINE,
      message: error.message.to_s,
      raw_log: error.raw_log.to_s
    }
  end
end
