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
    attr_writer :fetch_handler

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
      @fetch_handler = nil
      @intervals = {}
      @next_interval_id = 0
    end

    def [](key)
      return self if key == :performance

      @constructors.fetch(key)
    end

    # M11e: `JS.global.fetch(url)` は実際のruby.wasmでも bare method call
    # (method_missingで`.call(:fetch, url)`相当)として使われている
    # (webgl/sample/neon-error.rb、webgl/lib/glslkit/webgl/live_reload.rb)。
    # テストごとに `JS.global.fetch_handler = ->(url) { FakePromise... }` を
    # 設定する。
    def fetch(url)
      raise "no fetch_handler registered for #{url.inspect}" unless @fetch_handler

      @fetch_handler.call(url)
    end

    def call(name, *args)
      case name
      when :now
        Object.new(@now)
      when :requestAnimationFrame
        @frames << args.first
        Object.new(@frames.length)
      when :setInterval
        @next_interval_id += 1
        @intervals[@next_interval_id] = args.fetch(0)
        Object.new(@next_interval_id)
      when :clearInterval
        @intervals.delete(args.fetch(0).to_i)
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

    # M11e: setIntervalに登録されたコールバックを手動で1回呼ぶ
    # (next_frameのsetInterval版)。決定4により1ページにつきsetIntervalは
    # 1本のはずなので、最初の1本のみを対象にする。
    def tick_interval
      @intervals.values.first&.call
    end

    def interval_count
      @intervals.size
    end

    # `JS.global` はテスト間で共有されるシングルトンなので、テストの
    # setupで明示的にリセットしないと前のテストの登録が残ってしまう
    # (reset_framesと同じ理由)。
    def reset_intervals
      @intervals.clear
      @next_interval_id = 0
    end
  end

  True = Object.new(true)
  Null = Object.new(nil)
  Undefined = Object.new(nil)

  def self.global
    @global ||= Global.new
  end

  # M11e: 実際のPromise/then/catchの薄い同期版シミュレータ。FakeGL環境には
  # 本物のイベントループが無い(next_frame/tick_intervalのように呼び出し側が
  # 手動で進める)ため、resolved/rejectedをコンストラクタの時点で確定させる
  # 単純化をしている(実際のasyncの遅延は再現しない。「then/catchの連鎖と
  # then内でraiseした場合の伝播」だけを確認する用途)。
  class FakePromise
    def self.resolved(value)
      new(:resolved, value)
    end

    def self.rejected(error)
      new(:rejected, error)
    end

    def initialize(state, value)
      @state = state
      @value = value
    end

    def call(method_name, callback = nil)
      case method_name
      when :then
        then_call(callback)
      when :catch
        catch_call(callback)
      else
        raise "unexpected FakePromise call: #{method_name}"
      end
    end

    private

    def then_call(callback)
      return self if @state == :rejected

      result = callback.call(@value)
      result.is_a?(FakePromise) ? result : FakePromise.resolved(result)
    rescue => e
      FakePromise.rejected(e)
    end

    def catch_call(callback)
      return self if @state == :resolved

      callback.call(@value)
      FakePromise.resolved(nil)
    end
  end

  # fetchのResponseオブジェクトの薄いシミュレータ。
  class FakeResponse
    def initialize(ok:, status: 200, body: "")
      @ok = ok
      @status = status
      @body = body
    end

    def [](key)
      case key
      when :ok then @ok ? True : Object.new(false)
      when :status then Object.new(@status)
      end
    end

    def call(name)
      raise "unexpected FakeResponse call: #{name}" unless name == :text

      FakePromise.resolved(Object.new(@body))
    end
  end
end

class Array
  def to_js
    self
  end
end
