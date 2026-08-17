# frozen_string_literal: true

require "glslkit"
require "propshaft"
require_relative "rails/version"
require_relative "rails/compiler"
require_relative "rails/manifest_builder"
require_relative "rails/manifest_reader"
require_relative "rails/railtie"

module Glslkit
  module Rails
    # 注意: この名前空間の中では、素の定数`Rails`は`Glslkit::Rails`自身に
    # 解決される。トップレベルのRailsフレームワークではない。フレームワーク
    # を指すときは常に `::Rails` と書くこと (例: `::Rails::Engine`)。
  end
end
