# frozen_string_literal: true

require "open3"

# ダミーRailsアプリ(test/dummy)を、in-processで起動するのではなく
# bin/rails経由の実サブプロセスとして動かす — こうすることでテストは
# 実際のデプロイ環境と全く同じエントリポイントを通ることになり、
# 初期化順序に起因するバグが「既に起動済みのテストプロセス」の裏に
# 隠れてしまうことがない。
module DummyAppTestHelper
  DUMMY_ROOT = File.expand_path("dummy", __dir__)

  def run_in_dummy_app(*args, env: {})
    Open3.capture3(env, *args, chdir: DUMMY_ROOT)
  end
end
