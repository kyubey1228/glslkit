# frozen_string_literal: true

module Glslkit
  module Rails
    # ActionView上でincludeされるビューヘルパー (§4.3)。
    module Helper
      # <%= glsl_script_tag "pbr.vert" %>
      # => <script type="x-shader/x-vertex" id="pbr-vert">...</script>
      def glsl_script_tag(logical_path, **html_options)
        asset = find_glsl_asset(logical_path)
        html_options[:id] ||= glsl_script_id(logical_path.to_s)
        html_options[:type] = asset.content_type.to_s
        apply_glsl_nonce!(html_options)

        content_tag(:script, escape_closing_script_tags(asset.compiled_content).html_safe, html_options)
      end

      # <%= glsl_manifest_tag %>
      # => <script type="application/json" id="glsl-manifest">...</script>
      def glsl_manifest_tag(**html_options)
        html_options[:id] ||= "glsl-manifest"
        html_options[:type] = "application/json"
        apply_glsl_nonce!(html_options)

        content_tag(:script, escape_closing_script_tags(Glslkit::Rails.manifest.to_json).html_safe, html_options)
      end

      private

      def find_glsl_asset(logical_path)
        ::Rails.application.assets.load_path.find(logical_path.to_s) ||
          raise(ArgumentError, "no such glslkit asset: #{logical_path.inspect}")
      end

      # "pbr.vert" => "pbr-vert", "effects/glow.frag" => "effects-glow-frag"
      def glsl_script_id(logical_path)
        base = logical_path.sub(/\.(vert|frag|glsl)\z/, "")
        "#{base.tr("/", "-")}-#{Regexp.last_match(1)}"
      end

      # Rails自身のjavascript_tagがJS_ESCAPE_MAPで"</" => '<\/'として行っている
      # のと同じ理由・同じエスケープ: script要素の中身に文字通り"</"が現れると、
      # 中身がJS/JSONとして妥当かどうかに関わらずHTMLパーサがそこでタグを
      # 閉じてしまう。
      def escape_closing_script_tags(content)
        content.gsub("</", '<\/')
      end

      # javascript_tagと全く同じ3値のnonce解釈にする: true=強制、false=抑止、
      # 未指定なら ActionView::Helpers::JavaScriptHelper.auto_include_nonce
      # の場合だけ自動付与する。この auto_include_nonce は
      # config.content_security_policy_nonce_auto (デフォルトfalse。app側の
      # 明示的なopt-inが必要) に加えて、nonce_directivesがscript系
      # ディレクティブと交差していること、nonce_generatorが設定済みで
      # あることをRailsのAction Viewのrailtieが起動時に判定した結果。
      # content_security_policy? (このリクエストで実際にCSPが有効か) では
      # 判定しない — javascript_tag自身もそこは見ておらず、生成器さえ
      # 設定されていればnonceは発行されるため。
      def apply_glsl_nonce!(html_options)
        if html_options[:nonce] == false
          html_options.delete(:nonce)
        elsif html_options[:nonce] == true ||
            (!html_options.key?(:nonce) && ActionView::Helpers::JavaScriptHelper.auto_include_nonce)
          html_options[:nonce] = content_security_policy_nonce
        end
      end
    end
  end
end
