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
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
    nixos-anywhere.inputs.disko.follows = "disko";
    hermes-agent.url = "github:NousResearch/hermes-agent";
    hermes-agent.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";
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
      nixos-anywhere,
      hermes-agent,
      llm-agents,
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
        specialArgs = { inherit inputs nixpkgs-llama llm-agents; };
        modules = [
          determinate.nixosModules.default
          sops-nix.nixosModules.sops
          disko.nixosModules.default
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

      checks = forDevSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          vmTests = pkgs.callPackage ./tests {
            inherit nixpkgs sops-nix hermes-agent;
          };
        in
        {
          pre-commit-check = git-hooks.lib.${system}.run {
            src = ./.;
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
          };
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          # VM tests — QEMU only available on Linux.
          # Run with: nix build .#checks.x86_64-linux.<name>
          # See AGENTS.md for the testing ladder — use VM tests only for
          # activation script changes.
          inherit (vmTests)
            activation-github-auth
            vm-switch-smoke
            ;

          repowise-nix-tooling =
            let
              hostConfig = self.nixosConfigurations.nixos-hermes.config;
              hostPkgs = self.nixosConfigurations.nixos-hermes.pkgs;
              hermesExtraPackages = builtins.concatStringsSep "\n" (
                map toString hostConfig.services.hermes-agent.extraPackages
              );
              systemPackages = builtins.concatStringsSep "\n" (
                map toString hostConfig.environment.systemPackages
              );
            in
            pkgs.runCommand "repowise-nix-tooling" { } ''
              set -eu
              test '${hostPkgs.repowise.version}' = '0.10.0-repowise-nix'
              test -x '${hostPkgs.repowise}/bin/repowise'
              test -f '${./packages/repowise-nix/flake.nix}'
              test -f '${./packages/repowise-nix/patches/repowise-nix-language-support.patch}'
              grep -q -- 'inputs.repowise-nix.packages' '${./modules/packages.nix}'
              test -x '${hostPkgs.repowise-nix}/bin/repowise-nix'
              grep -q -- 'REPOWISE_DISABLE_EDITOR_SETUP' '${hostPkgs.repowise}/${hostPkgs.python313.sitePackages}/repowise/cli/editor_setup.py'
              '${hostPkgs.repowise}/bin/repowise' --help >/dev/null
              mkdir repo
              REPOWISE_REPO="$PWD/repo" '${hostPkgs.repowise-nix}/bin/repowise-nix' --help >/dev/null
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
              grep -q -- '${hostPkgs.repowise}' <<'EOF'
              ${systemPackages}
              EOF
              grep -q -- '${hostPkgs.repowise-nix}' <<'EOF'
              ${systemPackages}
              EOF
              touch $out
            '';

          agentmemory-service-config =
            let
              hostConfig = self.nixosConfigurations.nixos-hermes.config;
              unit = hostConfig.systemd.services.agentmemory;
              env = unit.environment;
              service = unit.serviceConfig;
              stateDirectories = pkgs.lib.toList service.StateDirectory;
              hermesMcp = hostConfig.services.hermes-agent.mcpServers.agentmemory;
              hermesPluginNames = builtins.concatStringsSep "\n" (
                map toString hostConfig.services.hermes-agent.extraPlugins
              );
              hermesEnabledPlugins = builtins.concatStringsSep " " hostConfig.services.hermes-agent.settings.plugins.enabled;
            in
            pkgs.runCommand "agentmemory-service-config" { } ''
              set -eu
              test '${if hostConfig.services.agentmemory.enable then "true" else "false"}' = 'true'
              test '${hostConfig.services.agentmemory.package.version}' = '0.9.21'
              test '${hostConfig.services.agentmemory.package.passthru.iii-engine.version}' = '0.11.2'
              test '${env.HOME}' = '/var/lib/agentmemory'
              test '${env.AGENTMEMORY_URL}' = 'http://127.0.0.1:3111'
              test '${env.AGENTMEMORY_VIEWER_URL}' = 'http://127.0.0.1:3113'
              test '${env.AGENTMEMORY_ALLOW_AGENT_SDK}' = 'false'
              test '${env.AGENTMEMORY_AUTO_COMPRESS}' = 'false'
              test '${env.GRAPH_EXTRACTION_ENABLED}' = 'false'
              test '${env.CONSOLIDATION_ENABLED}' = 'false'
              test '${env.AGENTMEMORY_INJECT_CONTEXT}' = 'false'
              test '${env.AGENTMEMORY_TOOLS}' = 'core'
              test '${env.III_REST_PORT}' = '3111'
              test '${env.III_STREAMS_PORT}' = '3112'
              test '${env.III_STREAM_PORT}' = '3112'
              test '${env.III_VIEWER_PORT}' = '3113'
              test '${env.III_ENGINE_URL}' = 'ws://127.0.0.1:49134'
              test '${service.User}' = 'agentmemory'
              test '${service.Group}' = 'agentmemory'
              test '${builtins.concatStringsSep " " stateDirectories}' = 'agentmemory agentmemory/data'
              test '${service.WorkingDirectory}' = '/var/lib/agentmemory'
              test '${hermesMcp.command}' = '${hostConfig.services.agentmemory.package}/bin/agentmemory'
              test '${builtins.concatStringsSep " " hermesMcp.args}' = 'mcp'
              test '${hermesMcp.env.AGENTMEMORY_URL}' = 'http://127.0.0.1:3111'
              agentmemory_plugin_path=$(grep -- 'agentmemory-hermes-plugin-0.9.21' <<'EOF' | head -n 1
              ${hermesPluginNames}
              EOF
              )
              test -n "$agentmemory_plugin_path"
              for hook in prefetch sync_turn on_session_end on_pre_compress on_memory_write system_prompt_block; do
                grep -q -- "- $hook" "$agentmemory_plugin_path/plugin.yaml"
              done
              grep -qw -- 'agentmemory' <<'EOF'
              ${hermesEnabledPlugins}
              EOF
              test '${hostConfig.services.hermes-agent.settings.memory.provider}' = 'nix-managed-agentmemory-hermes-plugin'
              test '${service.ProtectSystem}' = 'strict'
              test '${if service.ProtectHome then "true" else "false"}' = 'true'
              grep -q -- '/bin/iii --config ' <<'EOF'
              ${service.ExecStart}
              EOF
              grep -q -- '${pkgs.bash}/bin' <<'EOF'
              ${env.PATH}
              EOF
              grep -q -- '${hostConfig.services.agentmemory.package.passthru.iii-engine}/bin' <<'EOF'
              ${env.PATH}
              EOF
              grep -q -- 'agentmemory-iii-config.yaml' <<'EOF'
              ${service.ExecStart}
              EOF
              grep -q -- 'agentmemory-ready-check' <<'EOF'
              ${toString service.ExecStartPost}
              EOF
              grep -q -- '${pkgs.curl}/bin' <<'EOF'
              ${env.PATH}
              EOF
              case '${service.ExecStart}' in
                *'/bin/agentmemory --tools core'*)
                  echo 'agentmemory.service must supervise iii-engine directly, not the daemonizing CLI wrapper' >&2
                  exit 1
                  ;;
              esac
              touch $out
            '';

          netdata-service-config =
            let
              hostConfig = self.nixosConfigurations.nixos-hermes.config;
              netdataCfg = hostConfig.services.netdata;
              netdataUnit = hostConfig.systemd.services.netdata;
              hermesSupplementaryGroups = pkgs.lib.toList hostConfig.systemd.services.hermes-agent.serviceConfig.SupplementaryGroups;
              systemPackages = builtins.map (pkg: pkgs.lib.getName pkg) hostConfig.environment.systemPackages;
              netdataLoadCredentials = pkgs.lib.toList netdataUnit.serviceConfig.LoadCredential;
              netdataExecStartPost = pkgs.lib.toList netdataUnit.serviceConfig.ExecStartPost;
              netdataSupplementaryGroups = pkgs.lib.toList netdataUnit.serviceConfig.SupplementaryGroups;
              hermesNetdataMcp = hostConfig.services.hermes-agent.mcpServers.netdata;
              serviceNames = builtins.attrNames hostConfig.systemd.services;
              netdataConfigDirNames = builtins.attrNames netdataCfg.configDir;
            in
            pkgs.runCommand "netdata-service-config" { } ''
              set -eu
              test '${if netdataCfg.enable then "true" else "false"}' = 'true'
              test '${netdataCfg.package.version}' = '2.10.2'
              test '${if netdataCfg.enableAnalyticsReporting then "true" else "false"}' = 'false'
              test '${netdataCfg.config.web."bind to"}' = '127.0.0.1'
              test '${netdataCfg.config.plugins.freeipmi}' = 'no'
              test '${netdataCfg.config.plugins."logs-management"}' = 'no'
              test '${toString (builtins.elem "systemd-journal" netdataSupplementaryGroups)}' = '1'
              test '${hostConfig.sops.secrets.netdata-claim-conf.sopsFile}' = '${./hosts/hermes/secrets/netdata-claim.conf}'
              test '${toString (builtins.elem "netdata_claim_conf:${hostConfig.sops.secrets.netdata-claim-conf.path}" netdataLoadCredentials)}' = '1'
              grep -q -- 'netdata-install-cloud-claim-conf' <<'EOF'
              ${builtins.toString netdataUnit.serviceConfig.ExecStartPre}
              EOF
              grep -q -- 'netdata-cloud-claim' <<'EOF'
              ${builtins.toString netdataExecStartPost}
              EOF
              test '${toString (builtins.elem "netdata-observe" systemPackages)}' = '1'
              grep -q -- '/bin/nd-mcp-bridge' <<'EOF'
              ${hermesNetdataMcp.command}
              EOF
              test '${builtins.concatStringsSep " " hermesNetdataMcp.args}' = 'ws://127.0.0.1:19999/mcp'
              test '${toString (builtins.elem "systemd-journal" hermesSupplementaryGroups)}' = '1'
              test -d '${hostConfig.environment.etc."netdata/conf.d".source}/scripts.d'
              test -f '${hostConfig.environment.etc."netdata/conf.d".source}/scripts.d/nagios.conf'
              test '${if hostConfig.services.postgresql.enable then "true" else "false"}' = 'false'
              test '${
                if builtins.elem "go.d/postgres.conf" netdataConfigDirNames then "true" else "false"
              }' = 'false'
              test '${
                if builtins.elem "netdata-postgres-monitoring-setup" serviceNames then "true" else "false"
              }' = 'false'
              grep -q -- '127.0.0.1' '${hostConfig.environment.etc."netdata/netdata.conf".source}'
              grep -q -- '-D -c /etc/netdata/netdata.conf' <<'EOF'
              ${netdataUnit.serviceConfig.ExecStart}
              EOF
              touch $out
            '';

          hindsight-service-config =
            let
              hostConfig = self.nixosConfigurations.nixos-hermes.config;
              serviceNames = builtins.attrNames hostConfig.systemd.services;
              hermesMemory = hostConfig.services.hermes-agent.settings.memory;
              hermesEnvNames = builtins.attrNames hostConfig.services.hermes-agent.environment;
              hermesAfter = hostConfig.systemd.services.hermes-agent.after;
              hermesWants = hostConfig.systemd.services.hermes-agent.wants;
            in
            pkgs.runCommand "hindsight-service-config" { } ''
              set -eu
              test '${if hostConfig.services.hindsightMemory.enable then "true" else "false"}' = 'false'
              test '${hermesMemory.provider}' = 'agentmemory'
              test '${if builtins.elem "hindsight-embed" serviceNames then "true" else "false"}' = 'false'
              test '${if builtins.elem "hindsight-postgres-init" serviceNames then "true" else "false"}' = 'false'
              test '${if builtins.elem "llama-server" serviceNames then "true" else "false"}' = 'false'
              test '${if builtins.elem "hindsight-embed.service" hermesAfter then "true" else "false"}' = 'false'
              test '${if builtins.elem "hindsight-embed.service" hermesWants then "true" else "false"}' = 'false'
              test '${if builtins.elem "HINDSIGHT_MODE" hermesEnvNames then "true" else "false"}' = 'false'
              test '${if builtins.elem "HINDSIGHT_API_URL" hermesEnvNames then "true" else "false"}' = 'false'
              test '${if builtins.elem "HINDSIGHT_BANK_ID" hermesEnvNames then "true" else "false"}' = 'false'
              touch $out
            '';
        }
      );

      # Install-time CLIs exposed as flake apps so they use the same lockfile
      # pin as the NixOS modules. Invoke with:
      #   nix run .#nixos-anywhere -- --flake .#nixos-hermes ...
      #   nix run .#disko -- --mode disko hosts/hermes/disk-config.nix
      apps = forDevSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          prePrVerify = pkgs.writeShellApplication {
            name = "pre-pr-verify";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.git
              pkgs.nix
              pkgs.nixos-rebuild
            ];
            text = ''
              exec ${pkgs.bash}/bin/bash ${./tools/pre-pr-verify.sh} "$@"
            '';
          };
          hindsightContinuitySmoke = pkgs.writeShellApplication {
            name = "hindsight-continuity-smoke";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.python3
              pkgs.systemd
            ];
            text = ''
              exec ${pkgs.bash}/bin/bash ${./tools/hindsight-continuity-smoke.sh} "$@"
            '';
          };
        in
        {
          nixos-anywhere = {
            type = "app";
            program = "${nixos-anywhere.packages.${system}.nixos-anywhere}/bin/nixos-anywhere";
          };
          disko = {
            type = "app";
            program = "${disko.packages.${system}.disko}/bin/disko";
          };
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          pre-pr-verify = {
            type = "app";
            program = "${prePrVerify}/bin/pre-pr-verify";
          };
          hindsight-continuity-smoke = {
            type = "app";
            program = "${hindsightContinuitySmoke}/bin/hindsight-continuity-smoke";
          };
        }
      );
    };
}
