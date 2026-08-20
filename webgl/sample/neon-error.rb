# frozen_string_literal: true

# M10d: シェーダのコンパイルエラーが、includeされた元ファイルの名前と行番号を
# 指したままRubyの例外として上がってくることを見せるデモ。
#
# 壊れているのは common/sdf.glsl 側(webgl/sample/shaders-broken/)であり、
# neon.frag 直下ではない — エラーメッセージが「どのファイルの include 先が
# 壊れているか」まで教えてくれることが本gemの中核価値なので、あえて
# include の奥で壊している。
require_relative "../lib/glslkit/webgl"
require_relative "error_panel"
require_relative "generated-broken/neon-broken_shaders"
require_relative "generated/neon_shaders"

document = JS.global[:document]

set_text = ->(id, value) { document.call(:getElementById, id)[:textContent] = value.to_s }
set_status = ->(value) { set_text.call("status", value) }

build_program = ->(ctx, shaders, name) {
  ctx.program(Glslkit::Manifest.parse(shaders::MANIFEST), name,
    vertex: shaders::VERTEX, fragment: shaders::FRAGMENT,
    source_maps: {
      vertex: Glslkit::SourceMap.from_h(shaders::SOURCE_MAPS[:vertex]),
      fragment: Glslkit::SourceMap.from_h(shaders::SOURCE_MAPS[:fragment])
    })
}

fullscreen_triangle = {a_position: {data: [-1.0, -1.0, 3.0, -1.0, -1.0, 3.0], components: 2}}

start_render_loop = ->(ctx, program, geometry) {
  ctx.viewport
  program.set(:u_resolution, [ctx.width.to_f, ctx.height.to_f])
  ctx.loop do |seconds|
    program.set(:u_time, seconds)
    ctx.draw(geometry)
  end
}

# 壊れた行の前後を、includeされた元ファイル(common/sdf.glsl)自体から
# fetchして見せる(参考情報。任意)。file:// で開く等でfetchが失敗しても
# パネル本体(file/line/message/raw_log)の表示は壊さない。
show_source_excerpt = ->(file, line) do
  next unless line

  response = JS.global.fetch(file).await
  next unless response[:ok] == JS::True

  lines = response.text.await.to_s.split("\n", -1)
  from = [line - 3, 0].max
  to = [line + 2, lines.length - 1].min

  container = document.call(:getElementById, "excerpt")
  (from..to).each do |index|
    line_number = index + 1
    span = document.call(:createElement, "span")
    span[:className] = (line_number == line) ? "line error-line" : "line"
    span[:textContent] = format("%3d| %s", line_number, lines[index])
    container.call(:appendChild, span)
  end
rescue => _e
  nil
end

document.call(:getElementById, "retry").call(:addEventListener, "click") do
  ctx = Glslkit::WebGL.context("#canvas")
  program = build_program.call(ctx, NeonShaders, "neon")
  geometry = ctx.geometry(program: program, attributes: fullscreen_triangle)

  document.call(:getElementById, "panel")[:className] = ""
  set_status.call("正常版で描画中です。")
  start_render_loop.call(ctx, program, geometry)
end

begin
  ctx = Glslkit::WebGL.context("#canvas")
  build_program.call(ctx, NeonBrokenShaders, "neon-broken")
  set_status.call("想定外: 壊れているはずのシェーダが正常にコンパイルされました。")
rescue Glslkit::WebGL::CompileError => error
  described = NeonErrorPanel.describe(error)

  set_text.call("err-stage", described[:stage])
  set_text.call("err-file", described[:file])
  set_text.call("err-line", described[:line])
  set_text.call("err-message", described[:message])
  set_text.call("err-raw-log", described[:raw_log])
  document.call(:getElementById, "panel")[:className] = "visible"
  set_status.call("意図的に壊したシェーダの読み込みに失敗しました。")

  show_source_excerpt.call(error.file, error.line) if described[:resolved]
end
