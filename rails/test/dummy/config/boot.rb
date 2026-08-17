# frozen_string_literal: true

# This dummy app has no Gemfile of its own — it is a test fixture that boots
# inside the monorepo's top-level bundle (which path-references both gems).
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../../../Gemfile", __dir__)

require "bundler/setup"
