{
  description = "Hermes Agent";

  inputs = {
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";

    # Raw GitHub exception documented in AGENTS.md: this temporary package-set
    # pin supplies llama-cpp with Gemma 4 support while the primary FlakeHub
    # NixOS/nixpkgs/0 input lags host-required versions.
    nixpkgs-llama.url = "github:NixOS/nixpkgs/0726a0ecb6d4e08f6adced58726b95db924cef57";
    sops-nix.url = "https://flakehub.com/f/Mic92/sops-nix/0.1.1200";
    disko.url = "https://flakehub.com/f/nix-community/disko/*";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "https://flakehub.com/f/nix-community/home-manager/0.2511.*";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
    nixos-anywhere.inputs.disko.follows = "disko";
    # Pin Hermes Agent to maintainer-cut releases instead of default-branch
    # trunk. Upstream moves fast enough that unreleased commits deserve their
    # own validation branch, not a routine package refresh.
    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.5.28";
    hermes-agent.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents.url = "github:numtide/llm-agents.nix";
    # Keep GitButler on a separately validated llm-agents revision while allowing
    # the main llm-agents input to advance OMP and other agent tools.
    llm-agents-gitbutler.url = "github:numtide/llm-agents.nix/a7ad64dd500337232a35b5db16527475e8eec9a2";
    git-hooks.url = "https://flakehub.com/f/cachix/git-hooks.nix/*";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    repowise-nix.url = "path:./packages/repowise-nix";
    repowise-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-llama,
      determinate,
      sops-nix,
      disko,
      home-manager,
      nixos-anywhere,
      hermes-agent,
      llm-agents,
      llm-agents-gitbutler,
      git-hooks,
      ...
    }@inputs:
    let
      # Dev tools run on the contributor's machine, not the NixOS host.
      # Support both Apple Silicon and x86_64 Linux development environments.
      devSystems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forDevSystems = nixpkgs.lib.genAttrs devSystems;
      # treefmt-nix from llm-agents powers `nix fmt`.
      treefmt-nix = llm-agents.inputs.treefmt-nix;
    in
    {
      nixosConfigurations.nixos-hermes = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit
            inputs
            nixpkgs-llama
            llm-agents
            llm-agents-gitbutler
            ;
        };
        modules = [
          determinate.nixosModules.default
          sops-nix.nixosModules.sops
          disko.nixosModules.default
          home-manager.nixosModules.home-manager
          hermes-agent.nixosModules.default
          ./hosts/hermes
        ];
      };

      # Expose `nix fmt` for all dev systems.
      # Formats Nix files with nixfmt-rfc-style + deadnix (from ./treefmt.nix).
      formatter = forDevSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
        in
        treefmtEval.config.build.wrapper
      );

      devShells = forDevSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          hooks = self.checks.${system}.pre-commit-check;
        in
        {
          default = pkgs.mkShell {
            packages = hooks.enabledPackages ++ [
              pkgs.sops
              pkgs.prek
            ];
            shellHook = hooks.shellHook;
          };
        }
      );

      # Checks split across files (see AGENTS.md → "What Each Nix File Owns"):
      #   - pre-commit-check       ./checks/pre-commit.nix (all dev systems)
      #   - VM tests               ./tests           (x86_64-linux only)
      #   - eval-assertion checks  ./tests/eval      (x86_64-linux only)
      # Run with: nix build .#checks.x86_64-linux.<name>
      checks = forDevSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          linuxChecks =
            if system == "x86_64-linux" then
              let
                vmTests = pkgs.callPackage ./tests {
                  inherit nixpkgs sops-nix hermes-agent;
                };
                evalChecks = import ./tests/eval {
                  inherit pkgs;
                  hostSystem = self.nixosConfigurations.nixos-hermes;
                };
              in
              {
                # VM tests — QEMU only available on Linux.
                # See AGENTS.md for the testing ladder — use VM tests only for
                # activation script changes.
                inherit (vmTests)
                  activation-github-auth
                  vm-switch-smoke
                  ;
              }
              // evalChecks
            else
              { };
        in
        {
          pre-commit-check = import ./checks/pre-commit.nix {
            inherit pkgs git-hooks system;
          };
        }
        // linuxChecks
      );

      # Install-time CLIs and operational smokes (see ./apps/default.nix).
      apps = forDevSystems (
        system:
        import ./apps {
          inherit (nixpkgs) lib;
          inherit system nixos-anywhere disko;
          pkgs = nixpkgs.legacyPackages.${system};
        }
      );
    };
}
