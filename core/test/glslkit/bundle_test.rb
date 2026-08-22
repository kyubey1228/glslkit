# frozen_string_literal: true

require "test_helper"

class BundleTest < Minitest::Test
  VALID_VERTEX = "layout(location = 0) in vec3 a_position;\nuniform mat4 u_mvp;\nvoid main() {}\n"
  VALID_FRAGMENT = "out vec4 fragColor;\nvoid main() {}\n"

  def resolver(files)
    Glslkit::Resolvers::Hash.new(files)
  end

  def test_succeeds_and_returns_a_manifest_when_shaders_are_valid
    result = Glslkit::Bundle.build(
      resolver: resolver("a.vert" => VALID_VERTEX, "a.frag" => VALID_FRAGMENT),
      name: "a", vertex: "a.vert", fragment: "a.frag", now: Time.at(1_755_400_000)
    )

    assert result.ok?
    assert_nil result.kind
    assert_nil result.error
    assert_empty result.diagnostics
    refute_nil result.vertex
    refute_nil result.fragment
    assert_equal "a.vert", result.manifest["programs"]["a"]["stages"]["vertex"]["url"]
    assert_equal "2025-08-17T03:06:40Z", result.manifest["generated_at"]
  end

  def test_urls_can_be_overridden_for_callers_that_have_real_asset_urls
    result = Glslkit::Bundle.build(
      resolver: resolver("a.vert" => VALID_VERTEX, "a.frag" => VALID_FRAGMENT),
      name: "a", vertex: "a.vert", fragment: "a.frag",
      urls: {vertex: "/assets/a-abc.vert", fragment: "/assets/a-def.frag"}
    )

    stages = result.manifest["programs"]["a"]["stages"]
    assert_equal "/assets/a-abc.vert", stages["vertex"]["url"]
    assert_equal "/assets/a-def.frag", stages["fragment"]["url"]
  end

  def test_validation_failure_returns_a_result_instead_of_raising
    duplicate_location_vertex = <<~GLSL
      layout(location = 0) in vec3 a;
      layout(location = 0) in vec3 b;
      void main() {}
    GLSL

    result = Glslkit::Bundle.build(
      resolver: resolver("a.vert" => duplicate_location_vertex, "a.frag" => VALID_FRAGMENT),
      name: "a", vertex: "a.vert", fragment: "a.frag"
    )

    refute result.ok?
    assert_equal :validation, result.kind
    assert_nil result.manifest
    refute_nil result.vertex
    refute_nil result.fragment
    assert(result.diagnostics.any? { |d| d.code == "E004" })
  end

  def test_disabled_checks_are_forwarded_to_the_validator
    duplicate_location_vertex = <<~GLSL
      layout(location = 0) in vec3 a;
      layout(location = 0) in vec3 b;
      void main() {}
    GLSL

    result = Glslkit::Bundle.build(
      resolver: resolver("a.vert" => duplicate_location_vertex, "a.frag" => VALID_FRAGMENT),
      name: "a", vertex: "a.vert", fragment: "a.frag", disabled_checks: ["E004"]
    )

    assert result.ok?
    refute_nil result.manifest
  end

  def test_preprocess_failure_returns_a_result_instead_of_raising
    result = Glslkit::Bundle.build(
      resolver: resolver("a.frag" => VALID_FRAGMENT),
      name: "a", vertex: "missing.vert", fragment: "a.frag"
    )

    refute result.ok?
    assert_equal :preprocess, result.kind
    assert_kind_of Glslkit::IncludeNotFound, result.error
    assert_nil result.manifest
    assert_nil result.vertex
    assert_nil result.fragment
  end

  def test_unrecognized_exceptions_from_the_resolver_are_not_swallowed
    exploding_resolver = Object.new
    def exploding_resolver.read(...)
      raise ArgumentError, "boom"
    end

    assert_raises(ArgumentError) do
      Glslkit::Bundle.build(resolver: exploding_resolver, name: "a", vertex: "a.vert", fragment: "a.frag")
    end
  end

  def test_source_digest_is_computed_from_raw_bytes_of_all_dependent_files_including_includes
    fragment_with_include = "#include \"common.glsl\"\nout vec4 fragColor;\nvoid main() {}\n"
    files = {"a.vert" => VALID_VERTEX, "a.frag" => fragment_with_include, "common.glsl" => "float f() { return 1.0; }\n"}

    baseline = Glslkit::Bundle.build(resolver: resolver(files), name: "a", vertex: "a.vert", fragment: "a.frag")

    changed_files = files.merge("common.glsl" => "float f() { return 2.0; }\n")
    changed = Glslkit::Bundle.build(resolver: resolver(changed_files), name: "a", vertex: "a.vert", fragment: "a.frag")

    refute_equal baseline.source_digest, changed.source_digest
  end

  def test_source_digest_is_stable_for_identical_inputs
    files = {"a.vert" => VALID_VERTEX, "a.frag" => VALID_FRAGMENT}

    first = Glslkit::Bundle.build(resolver: resolver(files), name: "a", vertex: "a.vert", fragment: "a.frag")
    second = Glslkit::Bundle.build(resolver: resolver(files), name: "a", vertex: "a.vert", fragment: "a.frag")

    assert_equal first.source_digest, second.source_digest
  end

  def test_source_digest_on_preprocess_failure_falls_back_to_entry_points_when_there_is_no_known_files
    result = Glslkit::Bundle.build(
      resolver: resolver("a.frag" => VALID_FRAGMENT),
      name: "a", vertex: "missing.vert", fragment: "a.frag"
    )

    expected = Glslkit::Digest.hexdigest("a.frag\0#{VALID_FRAGMENT}")
    assert_equal expected, result.source_digest
  end

  def test_source_digest_on_preprocess_failure_includes_known_files_from_the_last_success
    result = Glslkit::Bundle.build(
      resolver: resolver("a.frag" => VALID_FRAGMENT, "a.vert" => VALID_VERTEX, "common.glsl" => "float f() { return 1.0; }\n"),
      name: "a", vertex: "missing.vert", fragment: "a.frag", known_files: ["a.vert", "common.glsl"]
    )

    # fallback_filesはknown_files + エントリポイント([vertex, fragment])。
    # "missing.vert"はresolverに存在しないため、digest計算時に読めず無視される
    # (read_rawの意図した劣化動作)。
    entries = ["a.frag\0#{VALID_FRAGMENT}", "a.vert\0#{VALID_VERTEX}", "common.glsl\0float f() { return 1.0; }\n"].sort
    assert_equal Glslkit::Digest.hexdigest(entries.join), result.source_digest
  end

  def test_line_directives_option_is_forwarded_to_the_preprocessor
    with_directives = Glslkit::Bundle.build(
      resolver: resolver("a.vert" => VALID_VERTEX, "a.frag" => VALID_FRAGMENT),
      name: "a", vertex: "a.vert", fragment: "a.frag", line_directives: true
    )
    without_directives = Glslkit::Bundle.build(
      resolver: resolver("a.vert" => VALID_VERTEX, "a.frag" => VALID_FRAGMENT),
      name: "a", vertex: "a.vert", fragment: "a.frag", line_directives: false
    )

    assert_includes with_directives.vertex.code, "#line"
    refute_includes without_directives.vertex.code, "#line"
  end
end
