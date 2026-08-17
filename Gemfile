# frozen_string_literal: true

source "https://rubygems.org"

gem "glslkit", path: "core"
gem "glslkit-rails", path: "rails"

group :development, :test do
  gem "rake", "~> 13.0"
  gem "minitest", "~> 5.0"
  gem "standard", "~> 1.3"
  gem "json_schemer", "~> 2.3" # spec/schema/reflection-v1.json の検証専用。どちらのgemの実行時依存でもない
end
