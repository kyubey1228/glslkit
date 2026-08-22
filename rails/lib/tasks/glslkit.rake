# frozen_string_literal: true

namespace :glslkit do
  desc "Generate the glslkit reflection manifest (config.assets.output_path/config.glslkit.manifest_path)"
  task reflect: :environment do
    app = Rails.application
    builder = Glslkit::Rails::ManifestBuilder.new(app)
    manifest = builder.build

    # config.glslkit.validateが有効な間は、precompileの入口でビルドを
    # 止める(SPEC.md §8.6)。マニフェストをファイルに書く前に検査すること
    # (壊れたシェーダの情報を含むマニフェストをpublic/に残さないため)。
    if builder.failing?
      message = builder.diagnostics.select(&:error?).join("\n")
      raise Glslkit::ValidationFailed, "glslkit validation failed:\n#{message}"
    end

    output_path = app.config.assets.output_path
    FileUtils.mkdir_p(output_path)
    File.write(output_path.join(app.config.glslkit.manifest_path), JSON.generate(manifest))
  end

  desc "Validate all glslkit shaders and exit non-zero on failure (ignores config.glslkit.validate)"
  task check: :environment do
    app = Rails.application
    builder = Glslkit::Rails::ManifestBuilder.new(app)
    builder.build

    errors = builder.diagnostics.select(&:error?)
    warnings = builder.diagnostics.select(&:warning?)

    builder.diagnostics.each { |diagnostic| puts diagnostic }

    # `rake glslkit:check` はconfig.glslkit.validateの設定に関わらず
    # 常に検証結果に基づいて成否を判定する(CI等での明示的な検査用)。
    abort("glslkit: #{errors.size} error(s)") if errors.any?
    abort("glslkit: #{warnings.size} warning(s)") if app.config.glslkit.fail_on_warning && warnings.any?
  end
end

# Propshaft自身のassets:precompile (propshaft/railties/assets.rake) の
# 後に実行される。そのためRails.application.assets.resolverは、その場での
# ファイルシステムスキャンではなく、Propshaftが直前に書いた.manifest.json
# を見て、そこからdigest付きURLを解決する。
Rake::Task["assets:precompile"].enhance do
  Rake::Task["glslkit:reflect"].invoke
end
