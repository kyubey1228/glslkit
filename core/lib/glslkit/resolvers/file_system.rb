# frozen_string_literal: true

require_relative "../errors"

module Glslkit
  module Resolvers
    # ディスク上のload_paths群に対して#includeのリクエストを解決する。
    # canonical_pathは常に、マッチしたload_pathからの相対パスとして表現される
    # (例 "common/math.glsl")。絶対パスになることはない —
    # この結果を元に作られるマニフェストはブラウザに配信されるものなので、
    # ローカルの絶対パスを漏らしてはならない。
    class FileSystem
      def initialize(load_paths:)
        @load_paths = load_paths.map { |path| File.expand_path(path) }
        @absolute_paths = {} # canonical_path => 絶対パス。相対探索のためのキャッシュ
      end

      def read(request, from: nil)
        absolute = resolve_absolute_path(request, from)
        canonical = canonicalize(absolute)
        @absolute_paths[canonical] = absolute
        [canonical, File.read(absolute)]
      end

      private

      def resolve_absolute_path(request, from)
        candidates = []
        candidates << File.expand_path(File.join(File.dirname(@absolute_paths.fetch(from)), request)) if from
        @load_paths.each { |load_path| candidates << File.expand_path(File.join(load_path, request)) }

        candidates.each do |candidate|
          next unless within_any_load_path?(candidate)
          return candidate if File.file?(candidate)
        end

        # 存在確認より先に境界チェックを行う(escapeしているのにたまたま存在
        # しないrequestに対してIncludeNotFoundを出すのではなく)。これにより
        # PathTraversalErrorの判定が、load_paths外に実際に何が存在するかに
        # 依存しなくなる。
        if candidates.any? { |candidate| !within_any_load_path?(candidate) }
          raise PathTraversalError, "#include #{request.inspect} escapes the configured load_paths"
        end

        raise IncludeNotFound, "could not resolve #include #{request.inspect}"
      end

      def within_any_load_path?(candidate)
        @load_paths.any? { |load_path| within?(load_path, candidate) }
      end

      def within?(load_path, candidate)
        candidate == load_path || candidate.start_with?("#{load_path}#{File::SEPARATOR}")
      end

      def canonicalize(absolute)
        load_path = @load_paths.find { |lp| within?(lp, absolute) }
        absolute.delete_prefix("#{load_path}#{File::SEPARATOR}")
      end
    end
  end
end
