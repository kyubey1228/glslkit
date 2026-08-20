# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "json"
require "json_schemer"
require "glslkit/webgl/embed"
require "glslkit/digest"

# Glslkit::WebGL::Embed はホスト側の生成ツールであり、ブラウザ/ruby.wasmの
# シミュレーションを一切必要としない。他のwebglテストと違いFakeGL/JSは使わない。
class EmbedTest < Minitest::Test
  FIXTURES = File.expand_path("fixtures/shaders", __dir__)
  GOLDEN = File.expand_path("fixtures/generated/hello_shaders.rb", __dir__)
  REFLECTION_SCHEMA = File.expand_path("../../spec/schema/reflection-v1.json", __dir__)
  SOURCE_MAP_SCHEMA = File.expand_path("../../spec/schema/source-map-v1.json", __dir__)

  def test_generated_output_matches_the_golden_file
    Dir.mktmpdir do |out_dir|
      Glslkit::WebGL::Embed.generate(shaders_dir: FIXTURES, out_dir: out_dir)
      generated = File.read(File.join(out_dir, "hello_shaders.rb"))
      assert_equal File.read(GOLDEN), generated
    end
  end

  # 修正1: heredoc_literal自体が、行のインデントに関わらずバイト一致で
  # 往復することを直接確認する。hello.vert/hello.fragはどの行も桁0から
  # 始まるため、`<<~`(squiggly)の不具合(共通インデントを勝手に削る)を
  # 再現しない。ここでは全行が2スペース下がっている合成データで確認する。
  def test_heredoc_literal_round_trips_byte_exact_with_uniformly_indented_code
    code = "  #version 300 es\n  layout(location = 0) in vec2 a;\n  void main() {\n    gl_Position = vec4(a, 0.0, 1.0);\n  }\n"

    literal = Glslkit::WebGL::Embed.heredoc_literal(code, "REGRESSION_TAG", suffix: ".freeze")
    restored = eval(literal) # rubocop:disable Security/Eval -- literal is our own generated heredoc source, not external input

    assert_equal code, restored
  end

  # 修正1: 埋め込んだVERTEX/FRAGMENT文字列がsource.codeとバイト一致している
  # ことを、冪等性テストとは別に確認する。`<<~`(squiggly)は最小共通インデント
  # を削るため、インデントが揃っていないcodeに対してはsource.codeと一致しない
  # 埋め込みを作りうる。digest一致はその代理検証になる
  # (digestはsource.codeそのものから計算されているため)。
  def test_embedded_source_digest_matches_the_manifest_stage_digest
    Dir.mktmpdir do |out_dir|
      Glslkit::WebGL::Embed.generate(shaders_dir: FIXTURES, out_dir: out_dir)
      load File.join(out_dir, "hello_shaders.rb")

      stages = HelloShaders::MANIFEST.fetch("programs").fetch("hello").fetch("stages")
      assert_equal stages.dig("vertex", "digest"), Glslkit::Digest.hexdigest(HelloShaders::VERTEX)
      assert_equal stages.dig("fragment", "digest"), Glslkit::Digest.hexdigest(HelloShaders::FRAGMENT)
    end
  end

  def test_generation_is_idempotent
    Dir.mktmpdir do |out_dir_a|
      Dir.mktmpdir do |out_dir_b|
        Glslkit::WebGL::Embed.generate(shaders_dir: FIXTURES, out_dir: out_dir_a)
        Glslkit::WebGL::Embed.generate(shaders_dir: FIXTURES, out_dir: out_dir_b)

        assert_equal(
          File.read(File.join(out_dir_a, "hello_shaders.rb")),
          File.read(File.join(out_dir_b, "hello_shaders.rb"))
        )
      end
    end
  end

  def test_generated_constants_round_trip_and_match_the_schemas
    Dir.mktmpdir do |out_dir|
      Glslkit::WebGL::Embed.generate(shaders_dir: FIXTURES, out_dir: out_dir)
      load File.join(out_dir, "hello_shaders.rb")

      manifest = Glslkit::Manifest.parse(HelloShaders::MANIFEST)
      assert_equal HelloShaders::MANIFEST, manifest.to_h

      vertex_map = Glslkit::SourceMap.from_h(HelloShaders::SOURCE_MAPS.fetch(:vertex))
      fragment_map = Glslkit::SourceMap.from_h(HelloShaders::SOURCE_MAPS.fetch(:fragment))
      assert_equal ["hello.vert", 2], vertex_map.resolve(2)
      # #include先(common/tint.glsl)の行を指すことを確認する。M10bの
      # #pragma once実演にも関わる、埋め込み後もSourceMapが機能する証拠。
      assert_equal ["common/tint.glsl", 2], fragment_map.resolve(3)

      reflection_schema = JSONSchemer.schema(JSON.parse(File.read(REFLECTION_SCHEMA)))
      manifest_doc = JSON.parse(JSON.generate(HelloShaders::MANIFEST))
      assert reflection_schema.valid?(manifest_doc), reflection_schema.validate(manifest_doc).to_a.inspect

      source_map_schema = JSONSchemer.schema(JSON.parse(File.read(SOURCE_MAP_SCHEMA)))
      [:vertex, :fragment].each do |stage|
        doc = JSON.parse(JSON.generate(HelloShaders::SOURCE_MAPS.fetch(stage)))
        assert source_map_schema.valid?(doc), source_map_schema.validate(doc).to_a.inspect
      end
    end
  end

  def test_validation_failure_raises_before_writing_anything
    Dir.mktmpdir do |shaders_dir|
      File.write(File.join(shaders_dir, "broken.vert"), <<~GLSL)
        layout(location = 0) in vec3 a;
        layout(location = 0) in vec3 b;
        void main() {}
      GLSL
      File.write(File.join(shaders_dir, "broken.frag"), "out vec4 c;\nvoid main() {}\n")

      Dir.mktmpdir do |out_dir|
        error = assert_raises(Glslkit::WebGL::Embed::ValidationError) do
          Glslkit::WebGL::Embed.generate(shaders_dir: shaders_dir, out_dir: out_dir)
        end
        assert_match(/E004/, error.message)
        assert_empty Dir.glob(File.join(out_dir, "*.rb"))
      end
    end
  end

  # 修正3: Validatorの警告(E002はwarning、SPEC.md §8.4)は生成を止めないが、
  # 握り潰さず標準エラーに出す。rakeタスク経由でなく Embed.generate を
  # 直接呼んでも見えることを確認する。
  def test_validator_warnings_are_written_to_stderr_but_do_not_stop_generation
    Dir.mktmpdir do |shaders_dir|
      # vertexにoutが無いため、fragmentのinに対応する相手がおらずE002(warning)。
      File.write(File.join(shaders_dir, "mismatch.vert"), "void main() {}\n")
      File.write(File.join(shaders_dir, "mismatch.frag"), "in vec2 v_uv;\nout vec4 c;\nvoid main() {}\n")

      Dir.mktmpdir do |out_dir|
        results = nil
        _stdout, stderr = capture_io { results = Glslkit::WebGL::Embed.generate(shaders_dir: shaders_dir, out_dir: out_dir) }

        assert_equal 1, results.size
        assert_equal 1, results.first.fetch(:warnings).size
        assert_equal "E002", results.first.fetch(:warnings).first.code
        assert_match(/E002/, stderr)
        assert_match(/v_uv/, stderr)
        assert_equal ["mismatch_shaders.rb"], Dir.glob(File.join(out_dir, "*.rb")).map { |p| File.basename(p) }
      end
    end
  end

  def test_vert_without_a_matching_frag_is_skipped
    Dir.mktmpdir do |shaders_dir|
      File.write(File.join(shaders_dir, "partial.vert"), "void main() {}\n")

      Dir.mktmpdir do |out_dir|
        results = Glslkit::WebGL::Embed.generate(shaders_dir: shaders_dir, out_dir: out_dir)
        assert_empty results
      end
    end
  end
end
