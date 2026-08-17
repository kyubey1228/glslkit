# frozen_string_literal: true

require "test_helper"

class ResolversFileSystemTest < Minitest::Test
  FIXTURES = File.expand_path("../../fixtures/shaders", __dir__)

  def test_reads_a_file_at_the_load_path_root
    resolver = Glslkit::Resolvers::FileSystem.new(load_paths: [File.join(FIXTURES, "simple")])

    canonical, content = resolver.read("entry.frag", from: nil)

    assert_equal "entry.frag", canonical
    assert_equal "#include \"included.glsl\"\n", content
  end

  def test_resolves_relative_to_the_includer_when_from_is_given
    resolver = Glslkit::Resolvers::FileSystem.new(load_paths: [File.join(FIXTURES, "relative")])
    resolver.read("entry.frag", from: nil) # "entry.frag"の内部キャッシュを作っておく

    canonical, = resolver.read("sub/foo.glsl", from: "entry.frag")
    canonical2, content = resolver.read("bar.glsl", from: canonical)

    assert_equal "sub/foo.glsl", canonical
    assert_equal "sub/bar.glsl", canonical2
    assert_equal "float bar_value() { return 42.0; }\n", content
  end

  def test_missing_file_raises_include_not_found
    resolver = Glslkit::Resolvers::FileSystem.new(load_paths: [File.join(FIXTURES, "missing_include")])

    assert_raises(Glslkit::IncludeNotFound) { resolver.read("nope.glsl", from: nil) }
  end

  def test_escaping_load_paths_raises_path_traversal_error
    resolver = Glslkit::Resolvers::FileSystem.new(load_paths: [File.join(FIXTURES, "path_traversal")])

    assert_raises(Glslkit::PathTraversalError) do
      resolver.read("../../../../etc/passwd", from: nil)
    end
  end
end
