# frozen_string_literal: true

module JS
  class Object
    def initialize(value = nil)
      @value = value
    end

    def [](key)
      return Object.new(@value.length) if key == :length && @value.respond_to?(:length)

      @value[key]
    end

    def []=(key, value)
      @value[key] = value
    end

    def to_i
      @value.to_i
    end

    def to_f
      @value.to_f
    end

    def to_s
      @value.to_s
    end

    def typeof
      @value.is_a?(Numeric) ? "number" : "object"
    end
  end

  class TypedArray < Object
    attr_reader :values

    def initialize(size_or_values)
      @value = size_or_values.is_a?(Integer) ? Array.new(size_or_values, 0) : size_or_values.dup
      @values = @value
    end

    def length
      @value.length
    end
  end

  class Constructor
    def new(size)
      TypedArray.new(size)
    end

    def call(name, values)
      raise "unexpected constructor call: #{name}" unless name == :from

      TypedArray.new(values)
    end
  end

  class Global
    def initialize
      @constructors = {
        Float32Array: Constructor.new,
        Int32Array: Constructor.new,
        Uint32Array: Constructor.new,
        Uint16Array: Constructor.new,
        Uint8Array: Constructor.new
      }
      @frames = []
      @now = 100.0
    end

    def [](key)
      return self if key == :performance

      @constructors.fetch(key)
    end

    def call(name, *args)
      case name
      when :now
        Object.new(@now)
      when :requestAnimationFrame
        @frames << args.first
        Object.new(@frames.length)
      else
        raise "unexpected global call: #{name}"
      end
    end

    def next_frame(timestamp)
      @frames.shift.call(Object.new(timestamp))
    end

    def reset_frames
      @frames.clear
    end
  end

  True = Object.new(true)
  Null = Object.new(nil)
  Undefined = Object.new(nil)

  def self.global
    @global ||= Global.new
  end
end

class Array
  def to_js
    self
  end
end
