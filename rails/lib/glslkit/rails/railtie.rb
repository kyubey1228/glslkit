# frozen_string_literal: true

require "rails/railtie"

module Glslkit
  module Rails
    class Railtie < ::Rails::Railtie
      config.glslkit = ActiveSupport::OrderedOptions.new
      config.glslkit.paths = ["app/shaders"]
      config.glslkit.minify = ::Rails.env.production?
      config.glslkit.line_directives = !::Rails.env.production?
      config.glslkit.manifest_path = "glsl-manifest.json"
      # M11a: SPEC.md §8.6。デフォルトで検証は有効、警告での失敗は無効。
      config.glslkit.validate = true
      config.glslkit.fail_on_warning = false
      config.glslkit.disabled_checks = []
      # M11c: SPEC-livereload.md §3.3。既定はdevelopmentでのみ有効。
      config.glslkit.live_reload = ::Rails.env.development?

      # Mime::Type.register を使う (Propshaft::Asset#content_type 自身が
      # 実際に使っている経路)。Marcelを直接使うことはしない — MarcelはPropshaft
      # の内部的・推移的な実装詳細に過ぎず、そこに結合すべきではない。
      initializer "glslkit.register_mime_types" do
        ::Mime::Type.register "x-shader/x-vertex", :vert unless ::Mime::Type.lookup_by_extension("vert")
        ::Mime::Type.register "x-shader/x-fragment", :frag unless ::Mime::Type.lookup_by_extension("frag")
        # register ではなく register_alias を使う: "text/plain" は既に
        # :text として登録済みなので、同じ文字列を :glsl として register で
        # 再登録するとそのlookupエントリを上書きしてしまう。
        ::Mime::Type.register_alias "text/plain", :glsl unless ::Mime::Type.lookup_by_extension("glsl")
      end

      initializer "glslkit.configure_propshaft", before: "propshaft.assets_middleware" do |app|
        app.config.glslkit.paths.each do |path|
          app.config.assets.paths << ::Rails.root.join(path).to_s
        end

        %w[x-shader/x-vertex x-shader/x-fragment text/plain].each do |mime_type|
          app.config.assets.compilers << [mime_type, Glslkit::Rails::Compiler]
        end
      end

      rake_tasks do
        load File.expand_path("../../tasks/glslkit.rake", __dir__)
      end

      # M11c: SPEC-livereload.md §3.3。利用者のroutes.rb編集を要求しないため、
      # ミドルウェアとして直接差し込む(`app.routes.append`によるmountは
      # RouteSetのfinalize!タイミングに対してrace conditionがあり、
      # 実機検証で再現性なく404になることが判明したため採用しなかった。
      # 詳細はLiveReload::Mountのコメントを参照)。config.glslkit.live_reload
      # が false(既定でproduction)ならミドルウェア自体を挿入しないため、
      # `/glslkit/*` は通常のルーティングに委ねられ存在しない扱いになる。
      initializer "glslkit.mount_live_reload" do |app|
        next unless app.config.glslkit.live_reload

        app.middleware.use Glslkit::Rails::LiveReload::Mount, Glslkit::Rails::LiveReload::Engine
      end

      initializer "glslkit.view_helpers" do
        ActiveSupport.on_load(:action_view) { include Glslkit::Rails::Helper }
      end
    end
  end
end
