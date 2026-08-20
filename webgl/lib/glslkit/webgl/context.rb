# frozen_string_literal: true

module Glslkit
  module WebGL
    class Context
      def self.from_selector(selector)
        document = JS.global[:document]
        canvas = document.call(:querySelector, selector)
        if canvas == JS::Null || canvas == JS::Undefined
          raise UnsupportedError, "canvas not found: #{selector}"
        end
        gl = canvas.call(:getContext, "webgl2")
        if gl == JS::Null || gl == JS::Undefined
          raise UnsupportedError, "WebGL2 is not available for #{selector}"
        end
        new(gl, canvas)
      end

      def initialize(gl, canvas)
        @gl = gl
        @canvas = canvas
        @performance = JS.global[:performance]
        @request_animation_frame = JS.global
        @programs = []
        @state = {program: nil}
      end

      def width
        @canvas[:width].to_i
      end

      def height
        @canvas[:height].to_i
      end

      def program(manifest, name, vertex:, fragment:, source_maps: {})
        manifest_hash = manifest.respond_to?(:to_h) ? manifest.to_h : manifest
        entry = manifest_hash.fetch("programs").fetch(name.to_s) do
          raise UnknownProgramError, "program not found in manifest: #{name}"
        end
        normalized_maps = source_maps.each_with_object({}) do |(stage, map), maps|
          maps[stage.to_sym] = map.is_a?(Hash) ? Glslkit::SourceMap.from_h(map) : map
        end
        created = Program.new(@gl, entry,
          vertex: vertex, fragment: fragment, source_maps: normalized_maps, state: @state)
        @programs << created
        @current_program = created
      end

      def geometry(attributes:, indices: nil, program: nil, mode: nil)
        target = program || @current_program
        raise UnknownProgramError, "create a program before creating geometry" unless target

        Geometry.new(@gl, target, attributes: attributes, indices: indices, mode: mode)
      end

      def texture2d(width:, height:, data:, unit: 0)
        Texture.new(@gl, width: width, height: height, data: data, unit: unit)
      end

      def viewport(width = nil, height = nil, x: 0, y: 0)
        @gl.call(:viewport, x, y, width || self.width, height || self.height)
        self
      end

      def depth_test=(enabled)
        @gl.call(enabled ? :enable : :disable, @gl[:DEPTH_TEST])
      end

      def clear(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0, depth: true)
        @gl.call(:clearColor, red, green, blue, alpha)
        mask = @gl[:COLOR_BUFFER_BIT].to_i
        mask |= @gl[:DEPTH_BUFFER_BIT].to_i if depth
        @gl.call(:clear, mask)
        self
      end

      def draw(geometry, program: nil)
        target = program || @current_program
        raise UnknownProgramError, "no program selected" unless target

        target.use
        @gl.call(:bindVertexArray, geometry.vao)
        if geometry.indexed
          @gl.call(:drawElements, geometry.mode, geometry.count, geometry.index_type, 0)
        else
          @gl.call(:drawArrays, geometry.mode, 0, geometry.count)
        end
        self
      end

      def loop(&block)
        raise ArgumentError, "block required" unless block

        start = @performance.call(:now).to_f
        tick = nil
        tick = proc do |timestamp|
          block.call((timestamp.to_f - start) / 1000.0)
          check_error if Glslkit::WebGL.debug
          @request_animation_frame.call(:requestAnimationFrame, tick)
        end
        @request_animation_frame.call(:requestAnimationFrame, tick)
        tick
      end

      private

      def check_error
        error = @gl.call(:getError).to_i
        return if error == @gl[:NO_ERROR].to_i

        raise Error, "WebGL error: #{error}"
      end
    end
  end
end
