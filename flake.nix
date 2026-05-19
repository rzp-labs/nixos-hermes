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
              test '${hostConfig.services.agentmemory.package.version}' = '0.9.18'
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
              grep -q -- 'agentmemory-hermes-plugin' <<'EOF'
              ${hermesPluginNames}
              EOF
              grep -qw -- 'agentmemory' <<'EOF'
              ${hermesEnabledPlugins}
              EOF
              test '${hostConfig.services.hermes-agent.settings.memory.provider}' = 'hindsight'
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
              grep -q -- "dsn: 'host=/var/run/postgresql dbname=postgres user=netdata'" '${
                hostConfig.environment.etc."netdata/conf.d".source
              }/go.d/postgres.conf'
              grep -q -- "collect_databases_matching: '*'" '${
                hostConfig.environment.etc."netdata/conf.d".source
              }/go.d/postgres.conf'
              grep -q -- "autodetection_retry: 60" '${
                hostConfig.environment.etc."netdata/conf.d".source
              }/go.d/postgres.conf'
              test '${
                toString (builtins.any (user: user.name == "netdata") hostConfig.services.postgresql.ensureUsers)
              }' = '1'
              grep -q -- 'GRANT pg_monitor TO netdata' <<'EOF'
              ${hostConfig.systemd.services.netdata-postgres-monitoring-setup.serviceConfig.ExecStart}
              EOF
              test '${hostConfig.systemd.services.netdata-postgres-monitoring-setup.serviceConfig.User}' = 'postgres'
              grep -q -- '127.0.0.1' '${hostConfig.environment.etc."netdata/netdata.conf".source}'
              grep -q -- '-D -c /etc/netdata/netdata.conf' <<'EOF'
              ${netdataUnit.serviceConfig.ExecStart}
              EOF
              touch $out
            '';

          hindsight-service-config =
            let
              hostConfig = self.nixosConfigurations.nixos-hermes.config;
              hindsightUnit = hostConfig.systemd.services.hindsight-embed;
              hindsightInitUnit = hostConfig.systemd.services.hindsight-postgres-init;
              llamaUnit = hostConfig.systemd.services.llama-server;
              envFile = builtins.head (pkgs.lib.toList hindsightUnit.serviceConfig.EnvironmentFile);
              llamaExec = llamaUnit.serviceConfig.ExecStart;
              hindsightExec = hindsightUnit.serviceConfig.ExecStart;
              hindsightExecStartPre = pkgs.lib.toList hindsightUnit.serviceConfig.ExecStartPre;
              hindsightSetupExec = builtins.elemAt hindsightExecStartPre 0;
              hindsightRecoveryExec = builtins.elemAt hindsightExecStartPre 1;
              hindsightRestartTriggers = pkgs.lib.toList hindsightUnit.restartTriggers;
              pgInitExec = hindsightInitUnit.serviceConfig.ExecStart;
              hermesMemory = hostConfig.services.hermes-agent.settings.memory;
              hermesEnv = hostConfig.services.hermes-agent.environment;
              hermesExtraPythonPackageNames = map (
                pkg: pkg.pname or ""
              ) hostConfig.services.hermes-agent.extraPythonPackages;
              hermesAfter = hostConfig.systemd.services.hermes-agent.after;
              hermesWants = hostConfig.systemd.services.hermes-agent.wants;
              hermesPythonPath = hostConfig.systemd.services.hermes-agent.environment.PYTHONPATH;
              hindsightActivation = hostConfig.system.activationScripts.hermes-hindsight-config.text;
            in
            pkgs.runCommand "hindsight-service-config" { } ''
              set -eu

              grep -qx 'LD_LIBRARY_PATH=.*gcc.*-lib/lib' ${envFile}
              grep -qx 'HINDSIGHT_API_LLM_PROVIDER=openai' ${envFile}
              grep -qx 'HINDSIGHT_API_LLM_BASE_URL=http://10.0.0.102:8317/v1' ${envFile}
              grep -qx 'HINDSIGHT_API_LLM_MODEL=gpt-5.4-mini' ${envFile}
              grep -qx 'HINDSIGHT_API_LLM_TIMEOUT=120' ${envFile}
              ! grep -q '^HINDSIGHT_API_LLM_API_KEY=' ${envFile}
              test '${toString (builtins.elem "cliproxyapi-key:${hostConfig.sops.secrets."cliproxyapi-key".path}" hindsightUnit.serviceConfig.LoadCredential)}' = '1'
              grep -qx 'HINDSIGHT_API_RETAIN_MAX_COMPLETION_TOKENS=4096' ${envFile}
              grep -qx 'HINDSIGHT_API_RETAIN_EXTRACTION_MODE=custom' ${envFile}
              grep -q 'top-level "facts" array' ${envFile}
              grep -q 'extract only the durable lesson' ${envFile}
              grep -qx 'HINDSIGHT_API_EMBEDDINGS_PROVIDER=openai' ${envFile}
              grep -qx 'HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL=google_gemma-4-E2B-it-Q6_K_L.gguf' ${envFile}
              grep -qx 'HINDSIGHT_API_RERANKER_PROVIDER=rrf' ${envFile}
              grep -qx 'HINDSIGHT_API_DATABASE_URL=postgresql:///hermes?host=/run/postgresql' ${envFile}
              test '${toString (builtins.elem "hindsight-client" hermesExtraPythonPackageNames)}' = '1'
              test '${toString (builtins.elem "aiohttp-retry" hermesExtraPythonPackageNames)}' = '1'
              test '${toString hostConfig.systemd.services.hermes-agent.serviceConfig.TimeoutStopSec}' = '240'
              test -f ${hermesPythonPath}/sitecustomize.py
              grep -q 'find_library(name' ${hermesPythonPath}/sitecustomize.py
              grep -q 'libopus.so.0' ${hermesPythonPath}/sitecustomize.py
              if grep -q 'hindsight_venv' ${hermesPythonPath}/sitecustomize.py; then
                echo 'sitecustomize.py must not add the Hindsight writable venv to sys.path' >&2
                exit 1
              fi
              if grep -q '/var/lib/hermes/.venv' ${hermesPythonPath}/sitecustomize.py; then
                echo 'sitecustomize.py must not reference the Hindsight writable venv' >&2
                exit 1
              fi
              test '${hermesMemory.provider}' = 'hindsight'
              test '${hermesEnv.HINDSIGHT_MODE}' = 'local_external'
              test '${hermesEnv.HINDSIGHT_API_URL}' = 'http://127.0.0.1:8888'
              test '${hermesEnv.HINDSIGHT_BANK_ID}' = 'hermes'
              test '${hermesEnv.HINDSIGHT_BUDGET}' = 'mid'
              test '${toString (builtins.elem "hindsight-embed.service" hermesAfter)}' = '1'
              test '${toString (builtins.elem "hindsight-embed.service" hermesWants)}' != '1'
              grep -q -- 'hermes-hindsight-config.json' <<'EOF'
              ${hindsightActivation}
              EOF
              grep -q -- 'hindsight/config.json' <<'EOF'
              ${hindsightActivation}
              EOF
              grep -q -- 'CREATE EXTENSION IF NOT EXISTS vector' ${pgInitExec}
              grep -q -- 'CREATE OR REPLACE FUNCTION public.schemas_with_pending_work' ${pgInitExec}
              grep -q -- 'RETURN NEXT NULL::text' ${pgInitExec}
              grep -q -- 'tenant_%' ${pgInitExec}
              grep -q -- '--embeddings' <<'EOF'
              ${llamaExec}
              EOF
              grep -q -- '--pooling' <<'EOF'
              ${llamaExec}
              EOF
              grep -q -- 'mean' <<'EOF'
              ${llamaExec}
              EOF
              ! grep -q -- '--chat-template' <<'EOF'
              ${llamaExec}
              EOF

              grep -q -- 'hindsight-api --host 127.0.0.1 --port 8888' ${hindsightExec}
              ! grep -q -- 'decommission-workers --yes' ${hindsightExec}
              test '${toString (builtins.length hindsightExecStartPre)}' = '2'
              grep -q -- 'hindsight_api.admin.cli' ${hindsightRecoveryExec}
              grep -q -- 'decommission-workers --yes' ${hindsightRecoveryExec}
              grep -q -- "to_regclass('public.async_operations')" ${hindsightRecoveryExec}
              grep -q -- 'timeout 15s' ${hindsightRecoveryExec}
              llm_preflight="$(sed -n 's#.* \(/nix/store/.*hindsight-llm-preflight.py\)$#\1#p' ${hindsightRecoveryExec})"
              test -n "$llm_preflight"
              grep -q -- '/models' "$llm_preflight"
              grep -q -- 'Authorization' "$llm_preflight"
              grep -q -- 'HINDSIGHT_API_LLM_MODEL' "$llm_preflight"
              grep -q -- 'Missing configured Hindsight LLM model' "$llm_preflight"
              test '${toString (builtins.elem envFile hindsightRestartTriggers)}' = '1'
              test '${toString (builtins.elem hindsightSetupExec hindsightRestartTriggers)}' = '1'
              test '${toString (builtins.elem hindsightRecoveryExec hindsightRestartTriggers)}' = '1'
              test '${toString (builtins.elem hindsightExec hindsightRestartTriggers)}' = '1'

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
