# frozen_string_literal: true

module Glslkit
  class UnknownTypeError < StandardError; end
  class IncludeNotFound < StandardError; end
  class PathTraversalError < StandardError; end
  class CircularIncludeError < StandardError; end
  class VersionConflictError < StandardError; end
  class StageMismatchError < StandardError; end
end
