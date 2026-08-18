# frozen_string_literal: true

module Glslkit
  module WebGL
    class Texture
      attr_reader :unit

      def initialize(gl, width:, height:, data:, unit: 0)
        @gl = gl
        @unit = unit
        @handle = gl.call(:createTexture)
        pixels = JS.global[:Uint8Array].call(:from, data.to_js)
        bind
        gl.call(:texImage2D, gl[:TEXTURE_2D], 0, gl[:RGBA], width, height, 0,
          gl[:RGBA], gl[:UNSIGNED_BYTE], pixels)
        gl.call(:texParameteri, gl[:TEXTURE_2D], gl[:TEXTURE_MIN_FILTER], gl[:NEAREST])
        gl.call(:texParameteri, gl[:TEXTURE_2D], gl[:TEXTURE_MAG_FILTER], gl[:NEAREST])
      end

      def bind
        @gl.call(:activeTexture, @gl[:TEXTURE0].to_i + @unit)
        @gl.call(:bindTexture, @gl[:TEXTURE_2D], @handle)
        self
      end
    end
  end
end
