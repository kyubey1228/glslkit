# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

# `glslkit/runtime`(M8g、wasm向けの狭い入口)が本当に digest / preprocessor /
# reflection / minifier をロードしないことを確認する。
#
# 同一プロセス内では他のテストが既に `require "glslkit"`(test_helper経由)を
# 済ませてしまっているため、`$LOADED_FEATURES` を見ても何も分からない。
# 必ず素のRubyを別プロセスで起動して確認すること。
class RuntimeIsolationTest < Minitest::Test
  LIB_DIR = File.expand_path("../../lib", __dir__)

  def loaded_basenames_after(require_path)
    script = <<~RUBY
      $LOAD_PATH.unshift #{LIB_DIR.inspect}
      require #{require_path.inspect}
      puts $LOADED_FEATURES.map { |f| File.basename(f) }.join("\\n")
    RUBY

    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-e", script)
    assert status.success?, "subprocess failed: #{stderr}"
    stdout.split("\n")
  end

  def test_runtime_does_not_load_digest_preprocessor_reflection_or_minifier
    loaded = loaded_basenames_after("glslkit/runtime")

    refute loaded.any? { |b| b.include?("digest") }, "digest should not be loaded: #{loaded}"
    refute loaded.any? { |b| b.include?("preprocessor") }, "preprocessor should not be loaded: #{loaded}"
    refute loaded.any? { |b| b.include?("reflection") }, "reflection should not be loaded: #{loaded}"
    refute loaded.any? { |b| b.include?("minifier") }, "minifier should not be loaded: #{loaded}"
  end

  def test_runtime_does_load_manifest_and_source_map
    loaded = loaded_basenames_after("glslkit/runtime")

    assert_includes loaded, "manifest.rb"
    assert_includes loaded, "source_map.rb"
  end

  def test_full_entrypoint_still_loads_everything
    loaded = loaded_basenames_after("glslkit")

    assert loaded.any? { |b| b.include?("digest") }, "digest should be loaded: #{loaded}"
    assert_includes loaded, "preprocessor.rb"
    assert_includes loaded, "reflection.rb"
    assert_includes loaded, "minifier.rb"
  end

  def test_manifest_parse_does_not_trigger_digest_load
    script = <<~RUBY
      $LOAD_PATH.unshift #{LIB_DIR.inspect}
      require "glslkit/runtime"
      json = '{"schema_version":1,"generated_at":"2026-08-18T00:00:00Z","programs":{}}'
      Glslkit::Manifest.parse(json)
      loaded = $LOADED_FEATURES.map { |f| File.basename(f) }
      puts loaded.any? { |b| b.include?("digest") }
    RUBY

    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-e", script)
    assert status.success?, "subprocess failed: #{stderr}"
    refute_equal "true", stdout.strip
  end

  # M11b-2: 上のテスト群は「狭い入口が余計なものをロードしないか」(load過多)を
  # 見ている。これはその逆方向 — 「個々のファイルを他をrequireせず単独で
  # requireしたときに、load時点のコードが壊れないか」(require不足)を見る。
  # 各ファイルはrequire_relativeで自分の依存を宣言しているはずなので、
  # aggregator(glslkit.rb)を経由しない単独requireでも例外が出てはならない。
  #
  # これは「メソッドを呼んだときに初めて発覚するstdlib暗黙依存」
  # (`Manifest.build`の`.iso8601`がその例だった)までは捕まえない —
  # あくまでload時点(クラス/モジュール定義本体)の話であることに注意。
  def test_every_core_lib_file_can_be_required_standalone
    files = Dir.glob(File.join(LIB_DIR, "glslkit", "**", "*.rb")).sort
    refute_empty files

    failures = files.filter_map do |file|
      _stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-e", "require #{file.inspect}")
      "#{file}:\n#{stderr}" unless status.success?
    end

    assert_empty failures, failures.join("\n\n")
  end
end
