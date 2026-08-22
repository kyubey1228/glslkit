# frozen_string_literal: true

# 開発機(通常のCRuby)で実行するホスト側の生成ツール(M10a)。
# File/Dir、Preprocessor/Reflection/Validator/digestなどcoreのフル機能を使う。
# **`glslkit/webgl`(ブラウザ側ランタイムの入口)からは絶対にrequireしないこと。
# ruby.wasm上では実行しない。** `rake glslkit:embed` からのみ使う想定。
require "glslkit"
require "pp"
require "fileutils"

module Glslkit
  module WebGL
    module Embed
      # 冪等性のための固定値(実際の生成時刻ではない)。generated_atが実行の
      # たびに変わるとgit diffがノイズになるため、実時刻の代わりにこれを使う。
      EMBEDDED_TIMESTAMP = Time.at(0).utc

      class ValidationError < StandardError; end
      class InvalidProgramNameError < StandardError; end

      # 有効なRubyの定数名(1つの識別子として)であることを要求する。
      MODULE_NAME_PATTERN = /\A[A-Z][A-Za-z0-9_]*\z/

      module_function

      # shaders_dir配下の.vert/.fragペアごとに1つの.rbファイルをout_dirへ書き出す。
      # 戻り値は [{name:, path:, warnings: [Glslkit::Diagnostic]}, ...]。
      # Validatorでエラーがあれば書き出さず ValidationError を投げる
      # (SPEC.md §8.6: Validator#validate は必ず Manifest.build より前)。
      def generate(shaders_dir:, out_dir:)
        root = File.expand_path(shaders_dir)
        FileUtils.mkdir_p(out_dir)
        resolver = Glslkit::Resolvers::FileSystem.new(load_paths: [root])

        program_stage_paths(root).sort.map do |name, stages|
          write_program(resolver, name, stages, out_dir)
        end
      end

      # 実体(前処理→Program化→検証→Manifest組み立て)は Glslkit::Bundle が
      # 持つ(M11b)。ここは Bundle の結果を見て、生成物として書き出すか
      # 例外を投げるかを判断するだけの薄いラッパー。
      def write_program(resolver, name, stages, out_dir)
        module_name_for(name) # 実際にBundleを呼ぶ前に名前だけ先に検証する(fail fast)。
        result = Glslkit::Bundle.build(
          resolver: resolver, name: name, vertex: stages.fetch(:vertex), fragment: stages.fetch(:fragment),
          line_directives: false, now: EMBEDDED_TIMESTAMP
        )

        case result.kind
        when :preprocess
          raise result.error
        when :validation
          errors = result.diagnostics.select(&:error?)
          raise ValidationError, "glslkit:embed validation failed for #{name}:\n#{errors.join("\n")}"
        end

        # 警告は生成を止めない(エラーと違う)が、握り潰さず必ず標準エラーに出す。
        # rakeタスク経由でなく Embed.generate を直接呼んだ場合でも見えるように、
        # ここ(ライブラリ側)で出す。呼び出し側での二重出力は行わない。
        warnings = result.diagnostics.select(&:warning?)
        warnings.each { |warning| warn "[glslkit:embed] #{name}: #{warning}" }

        out_path = File.join(out_dir, "#{name}_shaders.rb")
        File.write(out_path, render(name: name, manifest: result.manifest, vertex: result.vertex, fragment: result.fragment))
        {name: name, path: out_path, warnings: warnings}
      end

      # {"hello" => {vertex: "hello.vert", fragment: "hello.frag"}, ...} を返す。
      # 同名の相方が無い.vert/.fragはスキップする(rails側のManifestBuilderと同じ扱い)。
      def program_stage_paths(root)
        by_name = Hash.new { |h, k| h[k] = {} }
        Dir.glob("**/*.{vert,frag}", base: root).each do |relative|
          ext = File.extname(relative)
          stage = (ext == ".vert") ? :vertex : :fragment
          by_name[relative.delete_suffix(ext)][stage] = relative
        end
        by_name.select { |_, stages| stages.key?(:vertex) && stages.key?(:fragment) }
      end

      def render(name:, manifest:, vertex:, fragment:)
        module_name = module_name_for(name)
        vertex_tag = unique_tag(vertex.code, "GLSLKIT_VERTEX_SRC")
        fragment_tag = unique_tag(fragment.code, "GLSLKIT_FRAGMENT_SRC")

        <<~RUBY
          # frozen_string_literal: true

          # 自動生成 (rake glslkit:embed)。手で編集しない。
          # 再生成するには: bundle exec rake glslkit:embed[shaders_dir,out_dir]
          #
          # MANIFESTのgenerated_atが1970-01-01なのはバグではない。生成の
          # 冪等性(同じ入力から同じ出力になること)のための固定値であり、
          # 実行時刻を使うと同じ入力でも実行のたびにgit diffが出てしまう。
          # 再現性はstages.*.digest(実データから計算される)が担保している。

          module #{module_name}
            VERTEX = #{heredoc_literal(vertex.code, vertex_tag, suffix: ".freeze")}

            FRAGMENT = #{heredoc_literal(fragment.code, fragment_tag, suffix: ".freeze")}

            MANIFEST = #{pp_literal(manifest)}.freeze

            SOURCE_MAPS = {
              vertex: #{pp_literal(vertex.source_map.to_h)},
              fragment: #{pp_literal(fragment.source_map.to_h)}
            }.freeze
          end
        RUBY
      end

      # 非squiggly(`<<~`ではなく`<<`)のシングルクォートヒアドキュメントを使う。
      # `<<~`は最小共通インデントを削るため、code側の行のインデントが
      # 想定と揃っていないとsource.codeとバイト一致しなくなる
      # (例: 全行が2スペース下がっているとsource.codeの2スペースが
      # 削られてしまう)。`<<`は一切ディデントしないため常にバイト一致する。
      def heredoc_literal(code, tag, suffix: "")
        "<<'#{tag}'#{suffix}\n#{code.chomp}\n#{tag}"
      end

      # codeの中に偶然tagと同じ行が現れても壊れないよう、衝突する限りtagをずらす。
      # 冪等性のため決定的な連番だけを使う(object_idやSecureRandom等は不可)。
      def unique_tag(code, base)
        tag = base
        suffix = 2
        while code.lines.any? { |line| line.strip == tag }
          tag = "#{base}_#{suffix}"
          suffix += 1
        end
        tag
      end

      def pp_literal(value)
        PP.pp(value, +"", 80).chomp
      end

      # 規則(修正4): プログラム名を非英数字(`_` `-` `.` 等、任意の連続)で
      # 単語に分割し、各単語の先頭だけ大文字化して連結、末尾に "Shaders" を
      # 付ける。例: "neon" -> "NeonShaders"、"pbr_lighting" -> "PbrLightingShaders"、
      # "common.glsl" -> "CommonGlslShaders"(`.`も区切り文字として扱う)。
      #
      # 結果が有効なRubyの定数名でなければ(例: "2d-post" -> "2dPostShaders" は
      # 数字始まりで無効)、無言で辻褄を合わせようとせず例外を投げる。
      def module_name_for(name)
        words = name.to_s.split(/[^a-zA-Z0-9]+/).reject(&:empty?)
        camelized = words.map { |word| word[0].upcase + word[1..] }.join
        module_name = "#{camelized}Shaders"
        unless MODULE_NAME_PATTERN.match?(module_name)
          raise InvalidProgramNameError,
            "cannot derive a valid Ruby module name from program #{name.inspect} " \
            "(got #{module_name.inspect}). Rename the .vert/.frag pair so the shared " \
            "basename starts with a letter."
        end
        module_name
      end
    end
  end
end
