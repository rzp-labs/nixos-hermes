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
    home-manager.url = "https://flakehub.com/f/nix-community/home-manager/0";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
    nixos-anywhere.inputs.disko.follows = "disko";
    # Pin Hermes Agent to maintainer-cut releases instead of default-branch
    # trunk. Upstream moves fast enough that unreleased commits deserve their
    # own validation branch, not a routine package refresh.
    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.5.29.2";
    hermes-agent.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents.url = "github:numtide/llm-agents.nix";
    # Keep GitButler on a separately validated llm-agents revision while allowing
    # the main llm-agents input to advance OMP and other agent tools.
    llm-agents-gitbutler.url = "github:numtide/llm-agents.nix/c2ef928cbadd60280699e828973b14e21557c7ff";
    git-hooks.url = "https://flakehub.com/f/cachix/git-hooks.nix/*";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    repowise-nix.url = "path:./packages/repowise-nix";
    repowise-nix.inputs.nixpkgs.follows = "nixpkgs";
    den.url = "github:denful/den/v0.17.0";
    import-tree.url = "github:vic/import-tree";
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
          default = import ./shell.nix { inherit pkgs hooks; };
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
                  inherit
                    nixpkgs
                    sops-nix
                    hermes-agent
                    home-manager
                    ;
                  denModel = self.denModel;
                };
                evalChecks = import ./tests/eval {
                  inherit pkgs;
                  hostSystem = self.nixosConfigurations.nixos-hermes;
                  denModel = self.denModel;
                };
              in
              {
                # VM tests — QEMU only available on Linux.
                # See AGENTS.md for the testing ladder — use VM tests when a
                # build/eval cannot prove activation or runtime-shaped behavior.
                inherit (vmTests)
                  activation-github-auth
                  den-host-vm-smoke
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

      # Eval-only Den model surface. This is not the deployment output;
      # nixosConfigurations.nixos-hermes above remains the host source of truth.
      denModel =
        (nixpkgs.lib.evalModules {
          modules = [ ./den ];
          specialArgs = { inherit inputs; };
        }).config;
    };
}
