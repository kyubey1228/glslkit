# frozen_string_literal: true

require_relative "errors"
require_relative "preprocessor"
require_relative "program"
require_relative "validator"
require_relative "manifest"
require_relative "digest"

module Glslkit
  # 1プログラム分(vertex+fragment)を「前処理→Program化→検証→Manifest組み立て」
  # まで通す中間表現(M11b、SPEC-livereload.md §3.2)。core/rails/wasmのどれにも
  # 属さない — `Glslkit::WebGL::Embed` はこれを `.rb` に整形するだけの薄い
  # ラッパーになり、Rails側のライブリロードは同じ結果をJSONに整形して返す
  # (シリアライズ形式だけが違う、というのがこのクラスを切り出した理由)。
  #
  # `.build` は例外を投げない。前処理(#include解決)が失敗した場合も、
  # Validatorがエラーを返した場合も、結果は常に Result として返る。
  # 例外にして呼び出し側に伝える/伝えないの判断は呼び出し側の役目
  # (Embedは前者、Railsのライブリロードエンドポイントは後者になる想定)。
  module Bundle
    # Preprocessor#process とその内部で使うResolverが実際に投げうる例外を
    # 尽くす。ここに列挙されていない例外(想定外のバグ等)は握り潰さず
    # そのまま伝播させる。
    PREPROCESS_ERRORS = [
      IncludeNotFound,
      CircularIncludeError,
      VersionConflictError,
      PathTraversalError
    ].freeze

    # kind: nil(成功) | :preprocess(#include解決の失敗) | :validation(Validatorのエラー)。
    # kind == :validation でも vertex/fragment は入る(前処理自体は成功している)。
    # manifest は kind.nil? のときだけ入る。
    class Result
      attr_reader :name, :kind, :source_digest, :vertex, :fragment, :manifest, :diagnostics, :error

      def initialize(name:, source_digest:, kind: nil, vertex: nil, fragment: nil, manifest: nil, diagnostics: [], error: nil)
        @name = name
        @kind = kind
        @source_digest = source_digest
        @vertex = vertex
        @fragment = fragment
        @manifest = manifest
        @diagnostics = diagnostics
        @error = error
      end

      def ok?
        kind.nil?
      end
    end

    module_function

    # resolver: #include解決に使うResolver(呼び出し側が用意する。FileSystem/Hash等)。
    # vertex/fragment: resolverへ渡すエントリポイントのリクエスト文字列(相対パス)。
    # urls: Manifestのstage.urlに載せる値。省略時はvertex/fragmentのパス自身を使う
    #   (Embedの用途。実URLが要るRails側は明示的に渡す)。
    # known_files: ポーリング用digest(§3.2 決定1)を、前処理が失敗した回にも
    #   計算するための「前回成功時のfiles」。呼び出し側が持ち回る
    #   (Bundle自身はステートレスに保つ)。
    def build(resolver:, name:, vertex:, fragment:, line_directives: true, disabled_checks: [],
      urls: {vertex: vertex, fragment: fragment}, known_files: [], now: Time.now)
      preprocessor = Preprocessor.new(resolver: resolver, line_directives: line_directives)

      begin
        vertex_source = preprocessor.process(vertex)
        fragment_source = preprocessor.process(fragment)
      rescue *PREPROCESS_ERRORS => e
        digest = source_digest(resolver, fallback_files(known_files, [vertex, fragment]))
        return Result.new(name: name, kind: :preprocess, source_digest: digest, error: e)
      end

      program = Program.new(name: name, sources: {vertex: vertex_source, fragment: fragment_source})
      validation = Validator.new(disabled: disabled_checks).validate(program)
      digest = source_digest(resolver, (vertex_source.source_map.files + fragment_source.source_map.files).uniq)

      unless validation.ok?
        return Result.new(
          name: name, kind: :validation, source_digest: digest,
          vertex: vertex_source, fragment: fragment_source, diagnostics: validation.diagnostics
        )
      end

      manifest = Manifest.build(programs: [program], urls: {name => urls}, now: now)
      Result.new(
        name: name, source_digest: digest, vertex: vertex_source, fragment: fragment_source,
        manifest: manifest, diagnostics: validation.diagnostics
      )
    end

    def fallback_files(known_files, entry_points)
      (known_files.empty? ? entry_points : known_files + entry_points).uniq
    end

    # 依存する全ソースファイルの生バイト列(前処理後のコードではない)を
    # パスでソートして "path\0content" で連結し、SHA256を取る(決定1)。
    def source_digest(resolver, files)
      entries = files.sort.filter_map do |path|
        content = read_raw(resolver, path)
        "#{path}\0#{content}" unless content.nil?
      end
      Digest.hexdigest(entries.join)
    end

    # digest計算専用の再読み込み。known_filesに含まれる「前回成功時のファイル」が
    # その後削除されている等で読めなくなっていても、digest計算そのものは
    # 落とさない(ポーリングを壊さないことを優先する。digestは変化を検知できれば
    # 十分で、読めなかった1ファイルの厳密な反映までは求めない)。
    def read_raw(resolver, path)
      _, content = resolver.read(path, from: nil)
      content
    rescue
      nil
    end
  end
end
