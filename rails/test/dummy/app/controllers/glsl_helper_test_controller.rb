# frozen_string_literal: true

# ヘルパー(glsl_script_tag/glsl_manifest_tag)を実際のリクエスト/レスポンス
# サイクルを通して検証するためのテスト用コントローラ。
class GlslHelperTestController < ActionController::Base
  def show
    render inline: <<~ERB, layout: false
      <%= glsl_script_tag "pbr.vert" %>
      <%= glsl_manifest_tag %>
    ERB
  end

  def with_csp
    render inline: <<~ERB, layout: false
      <%= glsl_script_tag "pbr.vert" %>
    ERB
  end

  def nonce_suppressed
    render inline: <<~ERB, layout: false
      <%= glsl_script_tag "pbr.vert", nonce: false %>
    ERB
  end

  def escape_test
    render inline: <<~ERB, layout: false
      <%= glsl_script_tag "escape_test.frag", nonce: false %>
    ERB
  end

  def material
    render inline: <<~ERB, layout: false
      <%= glsl_script_tag "material.vert" %>
      <%= glsl_script_tag "material.frag" %>
      <%= glsl_manifest_tag %>
    ERB
  end

  content_security_policy(only: :with_csp) do |policy|
    policy.script_src :self
  end
end
