# frozen_string_literal: true

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.public_file_server.enabled = true

  # Precompile-only: no on-the-fly compile fallback, so a passing
  # assets:precompile test actually proves the manifest was written, rather
  # than silently succeeding via a live-compile path that masks a broken task.
  config.assets.compile = false

  # Redirects precompile output outside the repo during tests, so running the
  # test suite never leaves generated assets committed under test/dummy/public.
  if (public_root = ENV["GLSLKIT_TEST_PUBLIC_ROOT"])
    config.paths["public"] = public_root
  end
end
