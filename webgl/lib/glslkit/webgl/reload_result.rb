# frozen_string_literal: true

module Glslkit
  module WebGL
    # Context#reload_program(M11d、SPEC-livereload.md §4)の戻り値。
    # コンパイル/リンクの失敗(CompileError/LinkError)とattribute locationの
    # 不一致(ReloadIncompatibleError)は例外として投げる — これらは
    # 「差し替え自体が起きなかった」ことを意味し、呼び出し側が旧Programを
    # 使い続けるという単純な話で終わるため。
    #
    # ReloadResultが表すのは、差し替え自体は成功したが、一部のuniform値を
    # 引き継げなかった(名前が消えた/型やelement_countが変わった)という、
    # 差し替え後も動作は継続する軽微な話(§4.3)。診断はerrorにはならない
    # ため、ok?は常にtrueになる想定だが、将来の拡張に備えて診断のseverityを
    # 見て判定する形にしている。
    class ReloadResult
      attr_reader :diagnostics

      def initialize(diagnostics: [])
        @diagnostics = diagnostics
      end

      def ok?
        diagnostics.none? { |d| d.severity == :error }
      end
    end
  end
end
