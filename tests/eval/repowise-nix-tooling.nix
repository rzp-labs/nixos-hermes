# tests/eval/repowise-nix-tooling.nix
# Eval check: Repowise / vite-plus / cli-proxy-api tooling wiring.
#
# Pure-evaluation assertion derivation extracted from flake.nix.
# Built via: nix build .#checks.x86_64-linux.repowise-nix-tooling
{
  pkgs,
  hostConfig,
  hostPkgs,
  ...
}:
let
  hermesExtraPackages = builtins.concatStringsSep "\n" (
    map toString hostConfig.services.hermes-agent.extraPackages
  );
  systemPackages = builtins.concatStringsSep "\n" (
    map toString hostConfig.environment.systemPackages
  );
  adminHome = hostConfig.home-manager.users.admin;
  adminHomePackages = builtins.concatStringsSep "\n" (map toString adminHome.home.packages);
  adminHomeSessionPath = builtins.concatStringsSep "\n" adminHome.home.sessionPath;
  adminBashInit = adminHome.programs.bash.initExtra;
in
pkgs.runCommand "repowise-nix-tooling" { } ''
  set -eu
  test '${hostPkgs.repowise.version}' = '0.10.0-repowise-nix'
  test -x '${hostPkgs.repowise}/bin/repowise'
  test '${hostPkgs.vite-plus.version}' = '0.1.22'
  test -x '${hostPkgs.vite-plus}/bin/vp'
  test -x '${hostPkgs.vite-plus}/bin/vpx'
  test -x '${hostPkgs.vite-plus}/bin/vpr'
  '${hostPkgs.vite-plus}/bin/vp' --help >/dev/null
  '${hostPkgs.vite-plus}/bin/vpx' --help >/dev/null
  '${hostPkgs.vite-plus}/bin/vpr' --help >/dev/null
  '${hostPkgs.vite-plus}/bin/vp' env --help >/dev/null
  vp_home="$PWD/vp-home"
  mkdir -p "$vp_home/.vite-plus/bin"
  for tool in vp node npm npx vpx vpr; do
    ln -s ../current/bin/vp "$vp_home/.vite-plus/bin/$tool"
  done
  setup_output=$(HOME="$vp_home" PATH="${hostPkgs.vite-plus}/bin:${hostPkgs.nodejs}/bin:$PATH" '${hostPkgs.vite-plus}/bin/vp' env setup --refresh 2>&1)
  ! printf '%s\n' "$setup_output" | grep -q 'File exists (os error 17)'
  for tool in vp node npm npx vpx vpr; do
    test "$(readlink "$vp_home/.vite-plus/bin/$tool")" = '${hostPkgs.vite-plus}/bin/vp'
  done
  test '${hostPkgs.llm-agents.cli-proxy-api.version}' = '7.1.39'
  test -x '${hostPkgs.llm-agents.cli-proxy-api}/bin/cli-proxy-api'
  ('${hostPkgs.llm-agents.cli-proxy-api}/bin/cli-proxy-api' --version 2>&1 || true) | grep -q -- 'CLIProxyAPI Version: 7.1.39'
  test -f '${../../packages/repowise-nix/flake.nix}'
  test -f '${../../packages/repowise-nix/patches/repowise-nix-language-support.patch}'
  grep -q -- 'inputs.repowise-nix.packages' '${../../modules/packages.nix}'
  test -x '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- 'REPOWISE_DISABLE_EDITOR_SETUP' '${hostPkgs.repowise}/${hostPkgs.python313.sitePackages}/repowise/cli/editor_setup.py'
  grep -q -- 'unset PYTHONPATH' '${hostPkgs.repowise}/bin/repowise'
  '${hostPkgs.repowise}/bin/repowise' --help >/dev/null
  mkdir repo
  REPOWISE_REPO="$PWD/repo" '${hostPkgs.repowise-nix}/bin/repowise-nix' --help >/dev/null
  grep -q -- 'unset PYTHONPATH' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- '.repowise/\*\*' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- 'REPOWISE_EXTRA_EXCLUDES' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- 'REPOWISE_OPENAI_API_KEY' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- 'REPOWISE_OPENAI_BASE_URL' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- 'OPENAI_API_KEY="$REPOWISE_OPENAI_API_KEY"' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- 'OPENAI_BASE_URL="$REPOWISE_OPENAI_BASE_URL"' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- 'REPOWISE_EDITOR_SETUP' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- '--no-claude-md' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- 'REPOWISE_DISABLE_EDITOR_SETUP=1' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- "repowise-nix: REPOWISE_REPO='\$repo' does not exist" '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- 'read -r -a extra_excludes_arr' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- 'repowise reindex --embedder' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- '"\$@" .' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- 'repowise search "\$@" .' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  if REPOWISE_REPO="$PWD/missing" '${hostPkgs.repowise-nix}/bin/repowise-nix' status 2>err; then
    echo 'expected missing REPOWISE_REPO to fail' >&2
    exit 1
  fi
  grep -q -- "repowise-nix: REPOWISE_REPO='$PWD/missing' does not exist" err
  grep -q -- 'generate|refresh' '${hostPkgs.repowise-nix}/bin/repowise-nix'
  grep -q -- '${hostPkgs.repowise}' <<'EOF'
  ${hermesExtraPackages}
  EOF
  grep -q -- '${hostPkgs.repowise-nix}' <<'EOF'
  ${hermesExtraPackages}
  EOF
  grep -q -- '${hostPkgs.llm-agents.cli-proxy-api}' <<'EOF'
  ${systemPackages}
  EOF
  grep -q -- '${hostPkgs.vite-plus}' <<'EOF'
  ${adminHomePackages}
  EOF
  grep -q -- '${hostPkgs.nodejs}' <<'EOF'
  ${adminHomePackages}
  EOF
  grep -q -- '${hostPkgs.llm-agents.omp}' <<'EOF'
  ${adminHomePackages}
  EOF
  grep -q -- '.vite-plus/bin' <<'EOF'
  ${adminHomeSessionPath}
  EOF
  grep -q -- '.vite-plus/env' <<'EOF'
  ${adminBashInit}
  EOF
  ! grep -q -- '${hostPkgs.vite-plus}' <<'EOF'
  ${systemPackages}
  EOF
  ! grep -q -- '${hostPkgs.nodejs}' <<'EOF'
  ${systemPackages}
  EOF
  grep -q -- '${hostPkgs.repowise}' <<'EOF'
  ${systemPackages}
  EOF
  grep -q -- '${hostPkgs.repowise-nix}' <<'EOF'
  ${systemPackages}
  EOF
  touch $out
''
