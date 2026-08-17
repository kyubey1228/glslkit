# frozen_string_literal: true

require "json"

module Glslkit
  module Rails
    class << self
      # In production, reads the manifest written by `rake assets:precompile`
      # (memoized: the file doesn't change for the life of the process). In
      # development/test it's rebuilt on every call from the current shader
      # sources, matching config.glslkit.line_directives/minify's own
      # dev-vs-production split (SPEC.md §4.1, §4.4).
      def manifest
        if ::Rails.env.production?
          @manifest ||= read_precompiled_manifest
        else
          ManifestBuilder.new(::Rails.application).build
        end
      end

      private

      def read_precompiled_manifest
        JSON.parse(File.read(manifest_path))
      end

      def manifest_path
        config = ::Rails.application.config
        config.assets.output_path.join(config.glslkit.manifest_path)
      end
    end
  end
end
