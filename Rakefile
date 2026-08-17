# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test_core) do |t|
  t.libs << "core/lib" << "core/test"
  t.test_files = FileList["core/test/**/*_test.rb"]
end

Rake::TestTask.new(:test_rails) do |t|
  t.libs << "core/lib" << "rails/lib" << "rails/test"
  t.test_files = FileList["rails/test/**/*_test.rb"]
end

desc "Run all tests (core + rails)"
task test: [:test_core, :test_rails]

task default: :test
