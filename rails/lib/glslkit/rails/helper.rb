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

      # true=強制、false=抑止、未指定ならこのリクエストでCSPが実際に有効な
      # 場合だけ自動付与する。
      #
      # 当初は javascript_tag と全く同じ規約
      # (ActionView::Helpers::JavaScriptHelper.auto_include_nonce)に合わせて
      # いたが、これは config.content_security_policy_nonce_auto という
      # Rails 8.1で新規追加された設定に依存しており、railties >= 7.1という
      # このgemの依存下限では単純にメソッドが存在せずNoMethodErrorになる
      # (CIでRuby 3.1 → Rails 7.2に解決された際に発覚)。content_security_policy?
      # はRails 7.1時点から存在するので、こちらを使う。
      def apply_glsl_nonce!(html_options)
        if html_options[:nonce] == false
          html_options.delete(:nonce)
        elsif html_options[:nonce] == true ||
            (!html_options.key?(:nonce) && respond_to?(:content_security_policy?) && content_security_policy?)
          html_options[:nonce] = content_security_policy_nonce
        end
      end
    end
  end
end
