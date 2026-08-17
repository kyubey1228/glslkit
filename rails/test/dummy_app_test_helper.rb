# frozen_string_literal: true

require "open3"

# Drives the dummy Rails app (test/dummy) as a real subprocess via bin/rails,
# rather than booting it in-process — so these tests exercise the exact same
# entry point a deployed app would use, and initialization-order bugs can't
# hide behind an already-booted test process.
module DummyAppTestHelper
  DUMMY_ROOT = File.expand_path("dummy", __dir__)

  def run_in_dummy_app(*args, env: {})
    Open3.capture3(env, *args, chdir: DUMMY_ROOT)
  end
end
