# frozen_string_literal: true

module Glslkit
  module WebGL
    class Geometry
      attr_reader :vao, :count, :indexed, :index_type, :mode, :attribute_locations

      def initialize(gl, program, attributes:, indices: nil, mode: nil)
        @gl = gl
        @vao = gl.call(:createVertexArray)
        @mode = mode || gl[:TRIANGLES]
        # M11d: 構築時に実際に使ったattributeのlocationを保持する
        # (SPEC-livereload.md §4.2)。reload時、Contextがこれと新Programの
        # locationを突き合わせ、このGeometryのVAOがそのまま使えるかを判断する。
        @attribute_locations = {}
        gl.call(:bindVertexArray, @vao)
        build_attributes(program, attributes)
        build_indices(indices)
        gl.call(:bindVertexArray, JS::Null)
      end

      private

      def build_attributes(program, attributes)
        float32 = JS.global[:Float32Array]
        counts = []
        attributes.each do |name, config|
          location = program.attribute_locations.fetch(name.to_sym) do
            raise KeyError, "attribute not found in manifest: #{name}"
          end
          @attribute_locations[name.to_sym] = location
          next if location.to_i < 0

          components = config.fetch(:components)
          data = float32.call(:from, config.fetch(:data).to_js)
          buffer = @gl.call(:createBuffer)
          @gl.call(:bindBuffer, @gl[:ARRAY_BUFFER], buffer)
          @gl.call(:bufferData, @gl[:ARRAY_BUFFER], data, @gl[:STATIC_DRAW])
          @gl.call(:enableVertexAttribArray, location)
          @gl.call(:vertexAttribPointer, location, components, @gl[:FLOAT], false, 0, 0)
          counts << data[:length].to_i / components
        end
        @count = counts.min || 0
      end

      def build_indices(indices)
        @indexed = !indices.nil?
        return unless @indexed

        max = indices.max || 0
        constructor, @index_type = if max > 65_535
          [JS.global[:Uint32Array], @gl[:UNSIGNED_INT]]
        else
          [JS.global[:Uint16Array], @gl[:UNSIGNED_SHORT]]
        end
        data = constructor.call(:from, indices.to_js)
        buffer = @gl.call(:createBuffer)
        @gl.call(:bindBuffer, @gl[:ELEMENT_ARRAY_BUFFER], buffer)
        @gl.call(:bufferData, @gl[:ELEMENT_ARRAY_BUFFER], data, @gl[:STATIC_DRAW])
        @count = data[:length].to_i
      end
    end
  end
end
