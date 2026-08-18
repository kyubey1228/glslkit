# frozen_string_literal: true

require_relative "webgl/version"

begin
  require "js"
rescue LoadError => error
  raise LoadError,
    "glslkit-webgl requires a ruby.wasm runtime (the `js` gem, which ships with " \
    "ruby.wasm's browser builds, could not be loaded). This gem cannot run under " \
    "a normal CRuby/JRuby/TruffleRuby install — it only runs inside a browser " \
    "via ruby.wasm. See https://github.com/ruby/ruby.wasm for how to set that up.",
    error.backtrace
end

# glslkit-webgl は core の狭い入口(digestをロードしない)を使う。
# 前処理・解析・digest計算が要る `require "glslkit"` は使わないこと(M8g)。
begin
  require "glslkit/runtime"
rescue LoadError => error
  raise unless error.path == "glslkit/runtime"

  # Source-tree browser samples are loaded by JS::RequireRemote rather than an
  # installed gem. Packaged users take the normal require path above.
  require_relative "../../../core/lib/glslkit/runtime"
end

require_relative "webgl/errors"
require_relative "webgl/matrix"
require_relative "webgl/program"
require_relative "webgl/geometry"
require_relative "webgl/texture"
require_relative "webgl/context"

module Glslkit
  module WebGL
    class << self
      attr_accessor :debug

      def context(selector)
        Context.from_selector(selector)
      end
    end

    self.debug = false
  end
end
