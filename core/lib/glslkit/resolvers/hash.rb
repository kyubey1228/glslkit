# frozen_string_literal: true

require_relative "../errors"

module Glslkit
  module Resolvers
    # Looks requests up directly in a flat Hash of {request => content}.
    # Used by the wasm-side runtime (no filesystem) and in tests. `from` is
    # accepted for interface parity but ignored: there is no directory
    # structure to resolve relative to.
    class Hash
      def initialize(files)
        @files = files
      end

      def read(request, from: nil)
        content = @files[request]
        raise IncludeNotFound, "no such include: #{request.inspect}" unless content

        [request, content]
      end
    end
  end
end
