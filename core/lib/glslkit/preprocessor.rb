# frozen_string_literal: true

require "set"
require_relative "errors"
require_relative "source"
require_relative "source_map"
require_relative "reflection"

module Glslkit
  class Preprocessor
    INCLUDE_PATTERN = /\A[ \t]*#[ \t]*include[ \t]*(?:"([^"]+)"|<([^>]+)>)[ \t]*\z/
    VERSION_PATTERN = /\A[ \t]*#[ \t]*version\b/
    EXTENSION_PATTERN = /\A[ \t]*#[ \t]*extension\b/
    PRAGMA_ONCE_PATTERN = /\A[ \t]*#[ \t]*pragma[ \t]+once[ \t]*\z/

    def initialize(resolver:, line_directives: true)
      @resolver = resolver
      @line_directives = line_directives
    end

    def process(entry_request)
      run = Run.new
      canonical_path, content = @resolver.read(entry_request, from: nil)
      expand(run, canonical_path, content)

      header = []
      header << run.version if run.version
      header.concat(run.extensions)

      code = "#{(header + run.body).join("\n")}\n"
      Source.new(code: code, source_map: run.source_map, reflection: Reflection.new(code))
    end

    private

    # Mutable state threaded through one top-level #process call.
    class Run
      attr_accessor :version
      attr_reader :source_map, :extensions, :body, :ancestor_stack

      def initialize
        @source_map = SourceMap.new
        @extensions = []
        @extension_set = Set.new
        @pragma_once_seen = Set.new
        @ancestor_stack = []
        @body = []
      end

      def pragma_once?(canonical_path)
        @pragma_once_seen.include?(canonical_path)
      end

      def mark_pragma_once(canonical_path)
        @pragma_once_seen << canonical_path
      end

      def add_extension(value)
        return if @extension_set.include?(value)

        @extension_set << value
        @extensions << value
      end
    end
    private_constant :Run

    def expand(run, canonical_path, content)
      if run.ancestor_stack.include?(canonical_path)
        chain = (run.ancestor_stack + [canonical_path]).join(" -> ")
        raise CircularIncludeError, chain
      end

      file_index = run.source_map.index_for(canonical_path)
      run.ancestor_stack.push(canonical_path)
      needs_marker = true

      content.each_line.with_index(1) do |raw_line, lineno|
        line = raw_line.chomp

        case line
        when PRAGMA_ONCE_PATTERN
          run.mark_pragma_once(canonical_path)
          needs_marker = true
        when VERSION_PATTERN
          value = line.strip
          if run.version && run.version != value
            raise VersionConflictError, "#{run.version.inspect} vs #{value.inspect} (in #{canonical_path})"
          end
          run.version = value
          needs_marker = true
        when EXTENSION_PATTERN
          run.add_extension(line.strip)
          needs_marker = true
        when INCLUDE_PATTERN
          request = $1 || $2
          from = canonical_path if $1 # `<>` never resolves relative to the includer
          child_canonical, child_content = @resolver.read(request, from: from)
          expand(run, child_canonical, child_content) unless run.pragma_once?(child_canonical)
          needs_marker = true
        else
          if needs_marker
            run.body << "#line #{lineno} #{file_index}" if @line_directives
            needs_marker = false
          end
          run.body << line
        end
      end

      run.ancestor_stack.pop
    end
  end
end
