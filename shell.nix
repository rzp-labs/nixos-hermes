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
          tmp_hooks="$(mktemp -d)"
          trap 'rm -rf "$tmp_hooks"' EXIT

          for hook in pre-commit pre-push commit-msg; do
            if [ -f "$hooks_dir/$hook" ]; then
              cp "$hooks_dir/$hook" "$tmp_hooks/$hook"
            fi
          done

          ${hooks.shellHook}

          for hook in pre-commit pre-push commit-msg; do
            if [ -f "$tmp_hooks/$hook" ] && grep -q 'GITBUTLER_MANAGED_HOOK_V1' "$tmp_hooks/$hook"; then
              if [ -f "$hooks_dir/$hook" ] && ! grep -q 'GITBUTLER_MANAGED_HOOK_V1' "$hooks_dir/$hook"; then
                mv "$hooks_dir/$hook" "$hooks_dir/$hook-user"
                chmod +x "$hooks_dir/$hook-user"
              fi
              cp "$tmp_hooks/$hook" "$hooks_dir/$hook"
              chmod +x "$hooks_dir/$hook"
            fi
          done
        else
          ${hooks.shellHook}
        fi
      ''
    else
      "";
}
