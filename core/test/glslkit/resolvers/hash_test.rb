# frozen_string_literal: true

require "test_helper"

class ResolversHashTest < Minitest::Test
  def setup
    @resolver = Glslkit::Resolvers::Hash.new(
      "pbr.frag" => "void main() {}\n",
      "common/math.glsl" => "float pi() { return 3.14159; }\n"
    )
  end

  def test_reads_a_known_request
    canonical, content = @resolver.read("pbr.frag", from: nil)

    assert_equal "pbr.frag", canonical
    assert_equal "void main() {}\n", content
  end

  def test_ignores_from_since_there_is_no_directory_structure
    canonical, content = @resolver.read("common/math.glsl", from: "pbr.frag")

    assert_equal "common/math.glsl", canonical
    assert_equal "float pi() { return 3.14159; }\n", content
  end

  def test_unknown_request_raises_include_not_found
    assert_raises(Glslkit::IncludeNotFound) { @resolver.read("nope.glsl", from: nil) }
  end
end
