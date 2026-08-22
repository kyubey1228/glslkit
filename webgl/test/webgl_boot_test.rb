# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"

class WebglBootTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  WEBGL_LIB = File.join(ROOT, "webgl", "lib")
  CORE_LIB = File.join(ROOT, "core", "lib")

  def test_normal_cruby_reports_that_ruby_wasm_is_required
    env = {"RUBYLIB" => [WEBGL_LIB, CORE_LIB].join(File::PATH_SEPARATOR)}
    _stdout, stderr, status = Open3.capture3(
      env,
      RbConfig.ruby,
      "--disable-gems",
      "-e",
      'require "glslkit/webgl"'
    )

    refute status.success?
    assert_includes stderr, "glslkit-webgl requires a ruby.wasm runtime"
    assert_includes stderr, "could not be loaded"
    refute_match(/cannot load such file -- js\s*\z/, stderr)
  end

  def test_webgl_ruby_sources_do_not_call_class
    # self.class はJS::Objectではなく素のRubyレシーバに対する呼び出しであり
    # R6の懸念(JS値への#classがReflect.hasで例外になる)とは無関係なので除外する。
    # 1行に複数の`.class`があっても取りこぼさないよう、レシーバ単位で判定する
    # (行単位で「selfという文字列を含むか」だけを見ると、同じ行に本物の
    # 違反が同居していた場合に見逃すため)。
    sources = Dir.glob(File.join(ROOT, "webgl", "lib", "**", "*.rb"))
    violations = sources.each_with_object([]) do |path, found|
      File.foreach(path).with_index(1) do |line, number|
        receivers = line.scan(/(\w+)\.class\b/).flatten
        next if receivers.empty? || receivers.all? { |receiver| receiver == "self" }

        found << "#{path}:#{number}:#{line.strip}"
      end
    end

    assert_empty violations, "R6 violation(s):\n#{violations.join("\n")}"
  end

  def test_shim_is_boot_only_and_uses_require_remote
    shim = File.read(File.join(ROOT, "webgl", "shim", "glslkit-webgl.js"))

    assert_includes shim, 'require "js/require_remote/relative_shim"'
    assert_includes shim, "JS::RequireRemote.instance.load"
    refute_match(/requestAnimationFrame|Float32Array|Uint16Array|getContext/, shim)
    assert_operator shim.lines.length, :<=, 200
  end
end
