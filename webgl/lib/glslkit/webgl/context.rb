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

      # 手書きマニフェスト(M10a前調査5)はglslkitの検証を一切通らずに
      # ここまで来られてしまう。M10eでそのことに一度だけ気付けるようにする。
      # 例外にはしない(手書きマニフェストそのものを禁止する話ではない)。
      # プロセス内で1回だけ出す — Context.debugとは独立の、常時の警告。
      def self.warn_missing_generator_once
        return if @warned_missing_generator

        @warned_missing_generator = true
        warn "manifest has no generator field; hand-written manifests bypass " \
          "glslkit's validation. Use `rake glslkit:embed`."
      end

      def initialize(gl, canvas)
        @gl = gl
        @canvas = canvas
        @performance = JS.global[:performance]
        @request_animation_frame = JS.global
        @state = {program: nil}
        # M11d(reload_program、SPEC-livereload.md §4)専用の追跡状態。
        # development専用の機能であり、リークは許容する
        # (production相当の環境ではlive_reloadをrequireせず、ここが増え
        # 続ける経路自体を使わないため実害が無い。§4.1コメント参照)。
        @programs = {} # name(String) => Program
        @program_names = {}.compare_by_identity # Program => name(String)
        @geometries = Hash.new { |h, k| h[k] = [] } # name(String) => [Geometry]
      end

      def width
        @canvas[:width].to_i
      end

      def height
        @canvas[:height].to_i
      end

      def program(manifest, name, vertex:, fragment:, source_maps: {})
        manifest_hash = manifest.respond_to?(:to_h) ? manifest.to_h : manifest
        self.class.warn_missing_generator_once unless manifest_hash.key?("generator")
        entry = manifest_hash.fetch("programs").fetch(name.to_s) do
          raise UnknownProgramError, "program not found in manifest: #{name}"
        end
        normalized_maps = source_maps.each_with_object({}) do |(stage, map), maps|
          maps[stage.to_sym] = map.is_a?(Hash) ? Glslkit::SourceMap.from_h(map) : map
        end
        created = Program.new(@gl, entry,
          vertex: vertex, fragment: fragment, source_maps: normalized_maps, state: @state)
        register_program(name.to_s, created)
        @current_program = created
      end

      def geometry(attributes:, indices: nil, program: nil, mode: nil)
        target = program || @current_program
        raise UnknownProgramError, "create a program before creating geometry" unless target

        created = Geometry.new(@gl, target, attributes: attributes, indices: indices, mode: mode)
        program_name = @program_names[target]
        @geometries[program_name] << created if program_name
        created
      end

      # M11d: Program単体ではなくContextの責務(SPEC-livereload.md 決定2)。
      # 新しいシェーダのコンパイル・リンクが両方成功して初めて内部の
      # ハンドルを差し替える。失敗時は古いProgramのまま
      # CompileError/LinkErrorをそのまま投げる(§4.1)。
      #
      # attribute locationが新旧で変わっていた場合は、既存のVAOをそのまま
      # 使うと壊れた描画になるため、ReloadIncompatibleErrorを投げて
      # ページのリロードを促す(§4.2)。無言で壊れた描画を続けない。
      #
      # uniform値は名前ベースで引き継ぐ(§4.3)。名前・type・element_countが
      # すべて一致するものだけ復元し、それ以外は破棄してdiagnosticsに
      # 載せる(例外にはしない)。戻り値のResult#ok?はこの診断だけを見る —
      # コンパイル/リンク/location不一致は例外なので、ここまで来た時点で
      # 差し替え自体は成功している。
      def reload_program(name, vertex:, fragment:, manifest:, source_maps: {})
        key = name.to_s
        old_program = @programs.fetch(key) do
          raise UnknownProgramError, "no such program to reload (never created via Context#program): #{name}"
        end

        manifest_hash = manifest.respond_to?(:to_h) ? manifest.to_h : manifest
        entry = manifest_hash.fetch("programs").fetch(key) do
          raise UnknownProgramError, "program not found in manifest: #{name}"
        end
        normalized_maps = source_maps.each_with_object({}) do |(stage, map), maps|
          maps[stage.to_sym] = map.is_a?(Hash) ? Glslkit::SourceMap.from_h(map) : map
        end

        new_program = Program.new(@gl, entry,
          vertex: vertex, fragment: fragment, source_maps: normalized_maps, state: @state)

        check_geometry_compatibility!(key, new_program)

        discarded = new_program.restore_uniforms_from(old_program)
        diagnostics = discarded.map { |info| uniform_discard_diagnostic(key, info) }

        @programs[key] = new_program
        @program_names.delete(old_program)
        @program_names[new_program] = key
        @current_program = new_program if @current_program.equal?(old_program)

        ReloadResult.new(diagnostics: diagnostics)
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

      def register_program(name, created)
        @programs[name] = created
        @program_names[created] = name
      end

      # このプログラム名で作られた全Geometryについて、構築時に使った
      # attribute locationが新Programでも変わっていないかを確認する。
      # 1つでも変わっていればReloadIncompatibleError。
      def check_geometry_compatibility!(key, new_program)
        @geometries[key].each do |geometry|
          geometry.attribute_locations.each do |attribute_name, old_location|
            new_location = new_program.attribute_locations[attribute_name]
            next if new_location == old_location

            raise ReloadIncompatibleError,
              "attribute #{attribute_name} location changed (#{old_location.inspect} -> " \
                "#{new_location.inspect}) while reloading #{key}; reload the page"
          end
        end
      end

      def uniform_discard_diagnostic(program_name, discarded)
        message = case discarded.fetch(:reason)
        when :removed
          "uniform #{discarded.fetch(:name)} no longer exists in the reloaded shader; discarding its previous value"
        when :type_changed
          "uniform #{discarded.fetch(:name)} changed type (#{discarded.fetch(:from)} -> " \
            "#{discarded.fetch(:to)}); discarding its previous value"
        end
        Glslkit::Diagnostic.new(
          severity: :warning, code: "W101", message: message,
          program: program_name, stage: nil, name: discarded.fetch(:name).to_s, file: nil, line: nil
        )
      end

      def check_error
        error = @gl.call(:getError).to_i
        return if error == @gl[:NO_ERROR].to_i

        raise Error, "WebGL error: #{error}"
      end
    end
  end
end
