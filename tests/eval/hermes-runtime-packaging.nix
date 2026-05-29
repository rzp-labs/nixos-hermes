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
                test '${hermesPackage.version}' = '0.15.0'
                PYTHONPATH='${hostPkgs.opusCtypesShim}' '${hermesPackage.passthru.hermesVenv}/bin/python3' - <<'PY'
  import ctypes.util
  import importlib.util

  missing = [
      name
      for name in ["hermes_cli.proxy", "discord", "gateway", "hermes_cli.gateway"]
      if importlib.util.find_spec(name) is None
  ]
  if missing:
      raise SystemExit(f"missing runtime imports: {missing}")
  opus = ctypes.util.find_library("opus")
  if not opus or "libopus.so" not in opus:
      raise SystemExit(f"opus shim did not resolve libopus: {opus!r}")
  PY
                touch $out
''
