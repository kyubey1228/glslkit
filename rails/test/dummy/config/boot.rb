# frozen_string_literal: true

# このダミーアプリは自前のGemfileを持たない — monorepoのトップレベルの
# バンドル(両gemをpath参照している)の中で起動するテスト用フィクスチャ。
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../../../Gemfile", __dir__)

require "bundler/setup"
