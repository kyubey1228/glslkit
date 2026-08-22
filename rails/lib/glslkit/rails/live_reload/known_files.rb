# frozen_string_literal: true

module Glslkit
  module Rails
    module LiveReload
      # プログラム名ごとに「最後に成功したビルドの files」をプロセス内メモリで
      # 保持する。Glslkit::Bundle.build の `known_files:` に渡すためのもので、
      # 前処理が失敗した回でも意味のある source_digest を計算できるようにする
      # (SPEC-livereload.md §3.2 決定1)。development専用の機能なので永続化は
      # 不要（プロセスを跨いだ保持は求めない）。
      #
      # development でも Puma は複数スレッドで動くため、単純な Hash への
      # 読み書きではレースの余地がある。Mutex で保護する。
      module KnownFiles
        MUTEX = Mutex.new
        @files_by_name = {}

        module_function

        def fetch(name)
          MUTEX.synchronize { @files_by_name.fetch(name, []) }
        end

        def remember(name, files)
          MUTEX.synchronize { @files_by_name[name] = files }
        end
      end
    end
  end
end
