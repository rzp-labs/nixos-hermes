{
  description = "Nix packaging and portable workflow wrapper for Repowise";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          repowise = pkgs.callPackage ./package.nix { };
          repowise-nix = pkgs.callPackage ./wrapper.nix { inherit repowise; };
        in
        {
          inherit repowise repowise-nix;
          default = repowise-nix;
        }
      );

      apps = forSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.repowise-nix}/bin/repowise-nix";
        };
        repowise = {
          type = "app";
          program = "${self.packages.${system}.repowise}/bin/repowise";
        };
      });

      checks = forSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          repowise = self.packages.${system}.repowise;
          repowise-nix = self.packages.${system}.repowise-nix;
        in
        {
          repowise-nix-tooling = pkgs.runCommand "repowise-nix-tooling" { } ''
            set -eu
            test '${repowise.version}' = '0.10.0-repowise-nix'
            test -x '${repowise}/bin/repowise'
            test -x '${repowise-nix}/bin/repowise-nix'
            grep -q -- 'REPOWISE_DISABLE_EDITOR_SETUP' '${repowise}/${pkgs.python313.sitePackages}/repowise/cli/editor_setup.py'
            '${repowise}/bin/repowise' --help >/dev/null
            mkdir repo
            REPOWISE_REPO="$PWD/repo" '${repowise-nix}/bin/repowise-nix' --help >/dev/null
            grep -q -- '.repowise/\*\*' '${repowise-nix}/bin/repowise-nix'
            grep -q -- 'REPOWISE_EXTRA_EXCLUDES' '${repowise-nix}/bin/repowise-nix'
            grep -q -- 'REPOWISE_OPENAI_API_KEY' '${repowise-nix}/bin/repowise-nix'
            grep -q -- 'REPOWISE_OPENAI_BASE_URL' '${repowise-nix}/bin/repowise-nix'
            grep -q -- 'OPENAI_API_KEY="$REPOWISE_OPENAI_API_KEY"' '${repowise-nix}/bin/repowise-nix'
            grep -q -- 'OPENAI_BASE_URL="$REPOWISE_OPENAI_BASE_URL"' '${repowise-nix}/bin/repowise-nix'
            grep -q -- 'REPOWISE_EDITOR_SETUP' '${repowise-nix}/bin/repowise-nix'
            grep -q -- '--no-claude-md' '${repowise-nix}/bin/repowise-nix'
            grep -q -- 'REPOWISE_DISABLE_EDITOR_SETUP=1' '${repowise-nix}/bin/repowise-nix'
            grep -q -- "repowise-nix: REPOWISE_REPO='\$repo' does not exist" '${repowise-nix}/bin/repowise-nix'
            grep -q -- 'read -r -a extra_excludes_arr' '${repowise-nix}/bin/repowise-nix'
            grep -q -- 'repowise reindex --embedder' '${repowise-nix}/bin/repowise-nix'
            grep -q -- '"\$@" .' '${repowise-nix}/bin/repowise-nix'
            grep -q -- 'repowise search "\$@" .' '${repowise-nix}/bin/repowise-nix'
            if REPOWISE_REPO="$PWD/missing" '${repowise-nix}/bin/repowise-nix' status 2>err; then
              echo 'expected missing REPOWISE_REPO to fail' >&2
              exit 1
            fi
            grep -q -- "repowise-nix: REPOWISE_REPO='$PWD/missing' does not exist" err
            touch $out
          '';
        }
      );
    };
}
