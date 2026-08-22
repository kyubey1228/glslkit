# frozen_string_literal: true

require "action_controller/api"

module Glslkit
  module Rails
    module LiveReload
      # ライブリロードのポーリング対象になる2つのエンドポイント(§3.3)。
      # ActionController::API を使う(SPEC-livereload.md 決定7)。development
      # でのみマウントされる(Engine#config.glslkit.live_reload が false の
      # 場合は Railtie が一切マウントしないため、production ではこの
      # コントローラ自体にルーティングで到達できない)。
      #
      # Preprocessor/Validator の失敗は200 + ペイロードで返す(§3.4)。それ以外の
      # 想定外の例外はここで握り潰さず、素通しして500にする。
      class ProgramsController < ActionController::API
        # GET /glslkit/digests.json => {"neon" => "5059f642...", ...}
        # ソースdigest(決定1)のみを返す軽量エンドポイント。
        def digests
          digests = ShaderPrograms.discover(rails_app).each_with_object({}) do |(name, stages), acc|
            acc[name] = build(name, stages).source_digest
          end
          render json: digests
        end

        # GET /glslkit/programs/:name.json => §3.2 のJSON(失敗時は§3.4)。
        def show
          programs = ShaderPrograms.discover(rails_app)
          stages = programs[params[:name]]
          return head :not_found unless stages

          render json: payload_for(build(params[:name], stages))
        end

        private

        def rails_app
          ::Rails.application
        end

        def glslkit_config
          rails_app.config.glslkit
        end

        def build(name, stages)
          resolver = Glslkit::Resolvers::FileSystem.new(load_paths: ShaderPrograms.roots(rails_app))
          result = Glslkit::Bundle.build(
            resolver: resolver, name: name, vertex: stages.fetch(:vertex), fragment: stages.fetch(:fragment),
            line_directives: glslkit_config.line_directives, disabled_checks: glslkit_config.disabled_checks,
            known_files: KnownFiles.fetch(name)
          )
          KnownFiles.remember(name, (result.vertex.source_map.files + result.fragment.source_map.files).uniq) if result.ok?
          result
        end

        def payload_for(result)
          return success_payload(result) if result.ok?

          error_payload(result)
        end

        def success_payload(result)
          {
            name: result.name,
            source_digest: result.source_digest,
            vertex: result.vertex.code,
            fragment: result.fragment.code,
            manifest: result.manifest,
            source_maps: {vertex: result.vertex.source_map.to_h, fragment: result.fragment.source_map.to_h},
            diagnostics: result.diagnostics.map { |d| diagnostic_hash(d) }
          }
        end

        def error_payload(result)
          error = (result.kind == :validation) ? {diagnostics: result.diagnostics.map { |d| diagnostic_hash(d) }} : {message: result.error.message, class: result.error.class.name}

          {name: result.name, source_digest: result.source_digest, error: {kind: result.kind.to_s, **error}}
        end

        def diagnostic_hash(diagnostic)
          {
            severity: diagnostic.severity, code: diagnostic.code, message: diagnostic.message,
            program: diagnostic.program, stage: diagnostic.stage, name: diagnostic.name,
            file: diagnostic.file, line: diagnostic.line
          }.compact
        end
      end
    end
  end
end
