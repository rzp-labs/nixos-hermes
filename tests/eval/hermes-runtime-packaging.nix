# tests/eval/hermes-runtime-packaging.nix
# Eval check: hermes-agent runtime packaging (venv imports + opus shim).
#
# Pure-evaluation assertion derivation extracted from flake.nix.
# Built via: nix build .#checks.x86_64-linux.hermes-runtime-packaging
{
  pkgs,
  hostConfig,
  hostPkgs,
  ...
}:
let
  hermesCfg = hostConfig.services.hermes-agent;
  hermesPackage = hermesCfg.package.override {
    inherit (hermesCfg) extraDependencyGroups extraPythonPackages;
  };
in
pkgs.runCommand "hermes-runtime-packaging" { } ''
                set -eu
                test '${hermesPackage.version}' = '0.17.0'
                PYTHONPATH='${hostPkgs.opusCtypesShim}' '${hermesPackage.passthru.hermesVenv}/bin/python3' - <<'PY'
  import ctypes.util
  import importlib.util
  from pathlib import Path

  missing = [
      name
      for name in ["hermes_cli.proxy", "discord", "gateway", "hermes_cli.gateway", "cron.scheduler_provider"]
      if importlib.util.find_spec(name) is None
  ]
  if missing:
      raise SystemExit(f"missing runtime imports: {missing}")

  plugins_spec = importlib.util.find_spec("plugins")
  if plugins_spec is None or not plugins_spec.submodule_search_locations:
      raise SystemExit("missing bundled plugins package")
  plugin_roots = [Path(p) for p in plugins_spec.submodule_search_locations]
  manifests = [m for root in plugin_roots for m in root.rglob("plugin.y*ml")]
  if not manifests:
      raise SystemExit(f"bundled plugin manifests missing from sealed runtime: {plugin_roots}")

  opus = ctypes.util.find_library("opus")
  if not opus or "libopus.so" not in opus:
      raise SystemExit(f"opus shim did not resolve libopus: {opus!r}")
  PY
                touch $out
''
