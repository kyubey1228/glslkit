# frozen_string_literal: true

require_relative "glslkit/version"
require_relative "glslkit/errors"
require_relative "glslkit/types"
require_relative "glslkit/resolver"
require_relative "glslkit/resolvers/file_system"
require_relative "glslkit/resolvers/hash"
require_relative "glslkit/source_map"
require_relative "glslkit/source"
require_relative "glslkit/reflection"
require_relative "glslkit/preprocessor"
require_relative "glslkit/manifest"
require_relative "glslkit/minifier"
require_relative "glslkit/program"
require_relative "glslkit/diagnostic"
require_relative "glslkit/validator"
require_relative "glslkit/bundle"

module Glslkit
end
