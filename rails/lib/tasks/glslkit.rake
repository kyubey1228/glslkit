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

# Runs after Propshaft's own assets:precompile (propshaft/railties/assets.rake),
# so Rails.application.assets.resolver already sees Propshaft's just-written
# .manifest.json and resolves digested URLs from it rather than the live
# filesystem scan.
Rake::Task["assets:precompile"].enhance do
  Rake::Task["glslkit:reflect"].invoke
end
