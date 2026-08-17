# frozen_string_literal: true

module Glslkit
  # Duck-typed interface for resolving #include requests. Not meant to be
  # inherited from — Glslkit::Resolvers::FileSystem and ::Hash below simply
  # implement the same method shape. Rails' and a future ruby.wasm's own
  # resolvers only need to match this shape too.
  #
  #   read(request, from:) -> [canonical_path, content]
  #
  #     request        - the string written after #include, e.g. "common/math.glsl"
  #     from            - the includer's canonical_path, or nil at the entry
  #                       point (and also passed as nil for `#include <...>`,
  #                       which must skip relative resolution entirely)
  #     canonical_path  - a stable, load-path-relative identifier for the
  #                       resolved file (used for cycle detection, #pragma
  #                       once, and Glslkit::SourceMap#files)
  #
  #   Raise Glslkit::IncludeNotFound when request cannot be resolved.
  module Resolver
  end
end
