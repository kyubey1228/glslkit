# frozen_string_literal: true

module Glslkit
  Source = Struct.new(:code, :source_map, :reflection, :digest, keyword_init: true)
end
