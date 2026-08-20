# frozen_string_literal: true

require "rake/testtask"

# webgl/Rakefile の glslkit:embed タスクをリポジトリ直下からも呼べるようにする。
import "webgl/Rakefile"

Rake::TestTask.new(:test_core) do |t|
  t.libs << "core/lib" << "core/test"
  t.test_files = FileList["core/test/**/*_test.rb"]
end

Rake::TestTask.new(:test_rails) do |t|
  t.libs << "core/lib" << "rails/lib" << "rails/test"
  t.test_files = FileList["rails/test/**/*_test.rb"]
end

Rake::TestTask.new(:test_schema) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
end

Rake::TestTask.new(:test_webgl) do |t|
  t.libs << "core/lib" << "webgl/lib" << "webgl/test/support" << "webgl/test"
  t.test_files = FileList["webgl/test/**/*_test.rb"]
end

desc "Run all tests (core + rails + schema + webgl)"
task test: [:test_core, :test_rails, :test_schema, :test_webgl]

task default: :test
