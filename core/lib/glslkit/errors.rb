# frozen_string_literal: true

module Glslkit
  class UnknownTypeError < StandardError; end
  class IncludeNotFound < StandardError; end
  class PathTraversalError < StandardError; end
  class CircularIncludeError < StandardError; end
  class VersionConflictError < StandardError; end
  class StageMismatchError < StandardError; end
  # M11a: glslkit-railsのassets:precompileフックが、Validatorのエラーで
  # ビルドを止めるときに投げる(SPEC.md §8.6)。coreはこれを自分では投げない
  # (Rails側からしか使われないが、例外クラス自体は名前空間の都合でcoreに置く)。
  class ValidationFailed < StandardError; end
end
