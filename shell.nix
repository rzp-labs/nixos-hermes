{
  pkgs ? import <nixpkgs> { },
  hooks ? null,
}:
pkgs.mkShell {
  packages = (if hooks != null then hooks.enabledPackages else [ ]) ++ [
    pkgs.sops
    pkgs.prek
    pkgs.nixd
    pkgs.nil
    pkgs.alejandra
    pkgs.statix
    pkgs.deadnix
  ];
  shellHook =
    if hooks != null then
      ''
                git_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
                if [ -n "$git_dir" ] && [ -d "$git_dir/gitbutler" ]; then
                  echo "GitButler active: installing repo checks behind managed hooks."
                  hooks_dir="$git_dir/hooks"
                  repo_root="$(git rev-parse --show-toplevel)"
                  config_path="$repo_root/.pre-commit-config.yaml"

                  if [ ! -L "$config_path" ] || [ "$(readlink "$config_path" 2>/dev/null || true)" != "${hooks.config.configFile}" ]; then
                    [ -L "$config_path" ] && unlink "$config_path"
                    if [ -e "$config_path" ]; then
                      echo "git-hooks.nix: refusing to replace non-symlink .pre-commit-config.yaml" >&2
                      exit 1
                    fi
                    nix-store --add-root "$config_path" --indirect --realise "${hooks.config.configFile}"
                  fi

                  cat > "$hooks_dir/pre-commit-user" <<'EOF'
        #!/usr/bin/env bash
        set -euo pipefail
        unset GIT_DIR

        exec ${hooks.config.package}/bin/pre-commit hook-impl \
          --config=.pre-commit-config.yaml \
          --hook-type=pre-commit \
          --hook-dir "$(cd "$(dirname "$0")" && pwd)" \
          -- "$@"
        EOF
                  chmod +x "$hooks_dir/pre-commit-user"
                  rm -f \
                    "$hooks_dir/pre-commit.legacy" \
                    "$hooks_dir/pre-push-user" \
                    "$hooks_dir/pre-push.legacy"

                  if [ ! -f "$hooks_dir/pre-commit" ] || ! grep -q 'GITBUTLER_MANAGED_HOOK_V1' "$hooks_dir/pre-commit"; then
                    echo "GitButler-managed pre-commit hook missing; repo checks were written to pre-commit-user, but GitButler needs to restore the front hook before commits are fully protected." >&2
                  fi
                else
                  ${hooks.shellHook}
                fi
      ''
    else
      "";
}
