# frozen_string_literal: true

namespace :glslkit do
  desc "Generate the glslkit reflection manifest (config.assets.output_path/config.glslkit.manifest_path)"
  task reflect: :environment do
    app = Rails.application
    manifest = Glslkit::Rails::ManifestBuilder.new(app).build

    output_path = app.config.assets.output_path
    FileUtils.mkdir_p(output_path)
    File.write(output_path.join(app.config.glslkit.manifest_path), JSON.generate(manifest))
  end
end

# Propshaft自身のassets:precompile (propshaft/railties/assets.rake) の
# 後に実行される。そのためRails.application.assets.resolverは、その場での
# ファイルシステムスキャンではなく、Propshaftが直前に書いた.manifest.json
# を見て、そこからdigest付きURLを解決する。
Rake::Task["assets:precompile"].enhance do
  Rake::Task["glslkit:reflect"].invoke
end
