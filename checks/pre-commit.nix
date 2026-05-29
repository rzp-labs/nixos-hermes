# checks/pre-commit.nix — pre-commit hook configuration for `nix develop`
# and the `pre-commit-check` flake check.
#
# Returns the git-hooks.nix run result for the given system. The dev shell
# consumes `.enabledPackages` / `.shellHook`; the flake `checks` output
# exposes the whole derivation as `pre-commit-check`.
{
  pkgs,
  git-hooks,
  system,
}:
git-hooks.lib.${system}.run {
  src = ../.;
  hooks = {
    # Nix formatting
    nixfmt-rfc-style.enable = true;

    # Secret scanning — knows 150+ patterns
    gitleaks = {
      enable = true;
      name = "gitleaks";
      entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged --no-banner --config .gitleaks.toml";
      language = "system";
      pass_filenames = false;
      stages = [ "pre-commit" ];
    };

    # Catches bash pitfalls (set -u, unquoted globs, etc.) if shell scripts are added
    shellcheck.enable = true;

    # YAML validation — inline config to handle dotfile exclusion in nix sandbox
    yamllint = {
      enable = true;
      settings.configuration = ''
        extends: default
        rules:
          document-start: disable
          truthy: disable
          line-length:
            max: 120
            allow-non-breakable-words: true
            level: warning
        ignore: |
          hosts/hermes/secrets/
          tests/assets/
      '';
    };

    # GitHub Actions linting
    actionlint.enable = true;

    # Typo detection across all text files
    typos.enable = true;

    # General hygiene
    end-of-file-fixer.enable = true;
    trim-trailing-whitespace.enable = true;
    check-yaml.enable = true;
    check-added-large-files.enable = true;
  };
}
