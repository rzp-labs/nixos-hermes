# tests/eval/admin-home-profile.nix
# Eval check: standalone admin home profile tool exposure.
{
  pkgs,
  homeConfig,
  ...
}:
let
  homePath = homeConfig.config.home.path;
in
pkgs.runCommand "admin-home-profile" { } ''
  set -eu
  for tool in omp vp node bat glow yazi direnv; do
    test -x '${homePath}/bin/'"$tool"
  done
  touch $out
''
