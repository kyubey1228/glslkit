# frozen_string_literal: true

module Glslkit
  module WebGL
    class Program
      LOG_LINE_PATTERNS = [
        /(?:ERROR|WARNING):\s*\d+:(\d+):\s*(.*)/,
        /\b\d+\((\d+)\)\s*:\s*(?:error|warning)?\s*(.*)/i
      ].freeze

      attr_reader :handle, :attribute_locations

      def initialize(gl, manifest_program, vertex:, fragment:, source_maps: {}, state: nil)
        @gl = gl
        @state = state || {program: nil}
        @manifest_program = manifest_program
        @source_maps = source_maps
        @handle = build(vertex, fragment)
        @uniform_indices = {}
        @uniform_locations = []
        @uniform_setters = []
        @uniform_matrix = []
        @uniform_lengths = []
        @uniform_buffers = []
        prepare_uniforms
        prepare_attributes
      end

      def use
        unless @state[:program].equal?(@handle)
          @gl.call(:useProgram, @handle)
          @state[:program] = @handle
        end
        self
      end

      def set(name, value)
        index = @uniform_indices[name.to_sym]
        raise UnknownUniformError, "uniform not found in manifest: #{name}" unless index

        location = @uniform_locations[index]
        return self if null_location?(location)

        use
        buffer = @uniform_buffers[index]
        expected = @uniform_lengths[index]
        copy_value(buffer, value, expected, name)
        setter = @uniform_setters[index]
        if @uniform_matrix[index]
          @gl.call(setter, location, false, buffer)
        else
          @gl.call(setter, location, buffer)
        end
        self
      end

      private

      def build(vertex_source, fragment_source)
        vertex = compile(:vertex, vertex_source, @gl[:VERTEX_SHADER])
        fragment = compile(:fragment, fragment_source, @gl[:FRAGMENT_SHADER])
        program = @gl.call(:createProgram)
        @gl.call(:attachShader, program, vertex)
        @gl.call(:attachShader, program, fragment)
        @gl.call(:linkProgram, program)
        linked = @gl.call(:getProgramParameter, program, @gl[:LINK_STATUS])
        unless js_truthy?(linked)
          raw_log = @gl.call(:getProgramInfoLog, program).to_s
          @gl.call(:deleteProgram, program)
          raise LinkError, raw_log
        end
        @gl.call(:deleteShader, vertex)
        @gl.call(:deleteShader, fragment)
        program
      end

      def compile(stage, source, shader_type)
        shader = @gl.call(:createShader, shader_type)
        @gl.call(:shaderSource, shader, source)
        @gl.call(:compileShader, shader)
        compiled = @gl.call(:getShaderParameter, shader, @gl[:COMPILE_STATUS])
        return shader if js_truthy?(compiled)

        raw_log = @gl.call(:getShaderInfoLog, shader).to_s
        @gl.call(:deleteShader, shader)
        line, detail = parse_log(raw_log)
        resolved = line && @source_maps[stage]&.resolve(line)
        file, original_line = resolved if resolved
        raise CompileError.new(
          stage: stage,
          raw_log: raw_log,
          file: file,
          line: original_line,
          detail: detail
        )
      end

      def parse_log(raw_log)
        raw_log.each_line do |line|
          LOG_LINE_PATTERNS.each do |pattern|
            match = pattern.match(line)
            return [match[1].to_i, match[2].to_s.strip] if match
          end
        end
        [nil, nil]
      end

      def prepare_uniforms
        float32 = JS.global[:Float32Array]
        int32 = JS.global[:Int32Array]
        uint32 = JS.global[:Uint32Array]
        @manifest_program.fetch("uniforms").each_with_index do |uniform, index|
          name = uniform.fetch("name")
          @uniform_indices[name.to_sym] = index
          @uniform_locations[index] = @gl.call(:getUniformLocation, @handle, name)
          setter = uniform.fetch("setter").to_sym
          @uniform_setters[index] = setter
          @uniform_matrix[index] = uniform.fetch("matrix")
          @uniform_lengths[index] = uniform.fetch("element_count")
          constructor =
            if setter.to_s.end_with?("uiv")
              uint32
            elsif setter.to_s.end_with?("iv")
              int32
            else
              float32
            end
          @uniform_buffers[index] = constructor.new(@uniform_lengths[index])
        end
      end

      def prepare_attributes
        @attribute_locations = {}
        @manifest_program.fetch("attributes").each do |attribute|
          name = attribute.fetch("name")
          location = attribute["location"]
          location = @gl.call(:getAttribLocation, @handle, name).to_i if location.nil?
          @attribute_locations[name.to_sym] = location
        end
      end

      def copy_value(buffer, value, expected, name)
        if expected == 1 && !value.respond_to?(:length)
          buffer[0] = value
          return
        end

        actual = value[:length].to_i if value.is_a?(JS::Object)
        actual ||= value.length
        unless actual == expected
          raise UniformLengthError,
            "uniform #{name} expects #{expected} elements, got #{actual} from #{value}"
        end
        expected.times { |i| buffer[i] = value[i] }
      end

      def null_location?(location)
        location.nil? || location == JS::Null || location == JS::Undefined
      end

      def js_truthy?(value)
        value == true || value == JS::True
      end
    end
  end
end
