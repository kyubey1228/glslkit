# frozen_string_literal: true

require_relative "../errors"

module Glslkit
  module Resolvers
    # Resolves #include requests against a set of load paths on disk.
    # canonical_path is always expressed relative to whichever load path
    # matched (e.g. "common/math.glsl"), never as an absolute filesystem
    # path — the manifest this feeds into is servable to a browser, so local
    # paths must never leak into it.
    class FileSystem
      def initialize(load_paths:)
        @load_paths = load_paths.map { |path| File.expand_path(path) }
        @absolute_paths = {} # canonical_path => absolute path, for relative lookups
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

        # Bounds are checked before existence (rather than raising IncludeNotFound
        # for an escaping request that happens not to exist), so PathTraversalError
        # doesn't depend on what's actually on disk outside load_paths.
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
