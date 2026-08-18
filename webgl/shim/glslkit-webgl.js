(function () {
  "use strict";

  const script = document.currentScript;
  const entry = script && script.dataset.entry;
  const rubyVersion = (script && script.dataset.rubyVersion) || "4.0";
  const wasmWasiVersion = (script && script.dataset.wasmWasiVersion) || "2.10.1";

  if (!entry) {
    throw new Error("glslkit-webgl: data-entry must name the Ruby entry file");
  }

  const packageName = `@ruby/${rubyVersion}-wasm-wasi`;
  const packageRoot = `https://cdn.jsdelivr.net/npm/${packageName}@${wasmWasiVersion}/dist`;
  const wasmUrl = `${packageRoot}/ruby+stdlib.wasm`;
  const vmUrl = `https://cdn.jsdelivr.net/npm/@ruby/wasm-wasi@${wasmWasiVersion}/dist/browser/+esm`;

  async function compile(response) {
    if (!response.ok) {
      throw new Error(`glslkit-webgl: failed to fetch ruby.wasm (${response.status})`);
    }

    try {
      return await WebAssembly.compileStreaming(response.clone());
    } catch (_error) {
      return WebAssembly.compile(await response.arrayBuffer());
    }
  }

  async function boot() {
    const [{ DefaultRubyVM }, response] = await Promise.all([
      import(vmUrl),
      fetch(wasmUrl),
    ]);
    const module = await compile(response);
    const { vm } = await DefaultRubyVM(module);
    const baseUrl = new URL(".", new URL(entry, document.baseURI)).href;
    const feature = new URL(entry, document.baseURI).pathname.split("/").pop().replace(/\.rb$/, "");
    const ruby = [
      'require "js/require_remote/relative_shim"',
      `JS::RequireRemote.instance.base_url = ${JSON.stringify(baseUrl)}`,
      `JS::RequireRemote.instance.load(${JSON.stringify(feature)})`,
    ].join("\n");

    await vm.evalAsync(ruby);
  }

  window.glslkitWebGLReady = boot();
})();
