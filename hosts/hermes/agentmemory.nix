# Host-local Agent Memory parallel-observer service.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.agentmemory;
  stateDir = "/var/lib/agentmemory";
  dataDir = "${stateDir}/data";
  restPort = 3111;
  streamsPort = 3112;
  normalizedLlmBaseUrl = lib.removeSuffix "/" cfg.llm.baseUrl;
  viewerPort = 3113;
  enginePort = 49134;
  yaml = pkgs.formats.yaml { };
  agentmemoryRoot = "${cfg.package}/lib/node_modules/@agentmemory/agentmemory";
  startScript = pkgs.writeShellScript "agentmemory-start" ''
    set -eu
    ${lib.optionalString cfg.llm.enable ''
      # OMP's auth gateway is loopback-only and runs with --no-auth. Agent Memory
      # still needs a non-empty OpenAI-compatible key to select its LLM path, so
      # use a local sentinel instead of depending on the unreliable LAN CLIProxyAPI
      # secret route.
      export OPENAI_API_KEY=local-auth-gateway
    ''}
    exec ${lib.getExe cfg.package.passthru.iii-engine} --config ${iiiConfig}
  '';
  iiiConfig = yaml.generate "agentmemory-iii-config.yaml" {
    workers = [
      {
        name = "iii-worker-manager";
        config = {
          host = "127.0.0.1";
          port = enginePort;
        };
      }
      {
        name = "iii-http";
        config = {
          port = restPort;
          host = "127.0.0.1";
          default_timeout = 180000;
          cors = {
            allowed_origins = [
              "http://localhost:${toString restPort}"
              "http://localhost:${toString viewerPort}"
              "http://127.0.0.1:${toString restPort}"
              "http://127.0.0.1:${toString viewerPort}"
            ];
            allowed_methods = [
              "GET"
              "POST"
              "PUT"
              "DELETE"
              "OPTIONS"
            ];
          };
        };
      }
      {
        name = "iii-state";
        config.adapter = {
          name = "kv";
          config = {
            store_method = "file_based";
            file_path = "${dataDir}/state_store.db";
          };
        };
      }
      {
        name = "iii-queue";
        config.adapter.name = "builtin";
      }
      {
        name = "iii-pubsub";
        config.adapter.name = "local";
      }
      {
        name = "iii-cron";
        config.adapter = {
          name = "kv";
          config = {
            store_method = "file_based";
            file_path = "${dataDir}/cron_store.db";
          };
        };
      }
      {
        name = "iii-stream";
        config = {
          port = streamsPort;
          host = "127.0.0.1";
          adapter = {
            name = "kv";
            config = {
              store_method = "file_based";
              file_path = "${dataDir}/stream_store";
            };
          };
        };
      }
      {
        name = "iii-observability";
        config = {
          enabled = true;
          service_name = "agentmemory";
          exporter = "memory";
          sampling_ratio = 1.0;
          metrics_enabled = true;
          logs_enabled = true;
          logs_console_output = true;
        };
      }
      {
        name = "iii-exec";
        config.exec = [
          "${pkgs.nodejs}/bin/node ${agentmemoryRoot}/dist/index.mjs"
        ];
      }
    ];
  };
  readyCheck = pkgs.writeShellScript "agentmemory-ready-check" ''
    set -eu
    for _ in $(seq 1 30); do
      if ${pkgs.curl}/bin/curl -fsS --max-time 2 http://127.0.0.1:${toString restPort}/agentmemory/livez >/dev/null; then
        exit 0
      fi
      sleep 1
    done
    echo "agentmemory REST endpoints did not become ready" >&2
    exit 1
  '';
in
{
  options.services.agentmemory = {
    enable = lib.mkEnableOption "Agent Memory local parallel-observer service";

    package = lib.mkPackageOption pkgs "agentmemory" { };

    llm = {
      enable = lib.mkEnableOption "Agent Memory LLM enrichment through the local OMP OpenAI-compatible auth gateway";

      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:4000";
        description = ''
          Root URL for Agent Memory's OpenAI-compatible provider. Agent Memory
          0.9.21 appends /v1/chat/completions itself, so this must not include
          /v1. Use the local OMP auth gateway root instead of the old LAN
          CLIProxyAPI route so compression does not depend on cross-host
          networking after rebuilds.
        '';
      };

      model = lib.mkOption {
        type = lib.types.str;
        default = "gpt-5.4-mini";
        description = "OpenAI-compatible chat model routed by CLIProxyAPI.";
      };

      timeoutMs = lib.mkOption {
        type = lib.types.ints.positive;
        default = 120000;
        description = "Agent Memory LLM request timeout in milliseconds.";
      };

      embeddingProvider = lib.mkOption {
        type = lib.types.str;
        default = "local";
        description = ''
          Embedding provider used while OPENAI_API_KEY is present for chat LLM
          calls. Keep this explicit so adding the proxy key does not
          accidentally route embedding traffic through CLIProxyAPI.
        '';
      };
    };
  };

  config = lib.mkMerge [
    {
      services.agentmemory.enable = lib.mkDefault true;
      services.agentmemory.llm.enable = lib.mkDefault true;
    }

    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion =
            !cfg.llm.enable
            || lib.hasPrefix "http://" cfg.llm.baseUrl
            || lib.hasPrefix "https://" cfg.llm.baseUrl;
          message = "services.agentmemory.llm.baseUrl must start with http:// or https://.";
        }
        {
          assertion = !cfg.llm.enable || !(lib.hasSuffix "/v1" normalizedLlmBaseUrl);
          message = "services.agentmemory.llm.baseUrl must be the proxy root; Agent Memory appends /v1/chat/completions itself.";
        }
      ];

      users.users.agentmemory = {
        isSystemUser = true;
        group = "agentmemory";
        home = stateDir;
        createHome = false;
      };

      users.groups.agentmemory = { };

      services.hermes-agent = {
        environment = {
          AGENTMEMORY_URL = "http://127.0.0.1:${toString restPort}";
          # Keep the upstream plaintext-bearer guard enabled. The plugin allows
          # loopback HTTP, but will fail closed if a future secret-bearing config
          # drifts to plaintext HTTP on a non-loopback host.
          AGENTMEMORY_REQUIRE_HTTPS = "1";
        };

        # Agent Memory is now the active Hermes memory provider. Hindsight was
        # useful as a spike, but its retain/consolidation path proved too costly
        # and fragile to keep in the live assistant loop. Hermes' MemoryProvider
        # loader selects user-installed providers by their directory name under
        # $HERMES_HOME/plugins, and the NixOS module installs extraPlugins as
        # nix-managed-* symlinks. The plugin's internal name remains
        # "agentmemory" for the general plugin manager, but memory.provider must
        # match the symlink name for load_memory_provider() to find it.
        settings.memory.provider = "nix-managed-agentmemory-hermes-plugin";

        mcpServers.agentmemory = {
          command = lib.getExe cfg.package;
          args = [ "mcp" ];
          env.AGENTMEMORY_URL = "http://127.0.0.1:${toString restPort}";
          connect_timeout = 30;
          timeout = 120;
        };
      };

      systemd.services.agentmemory = {
        description = "Agent Memory parallel observer";
        after = [
          "network.target"
          "omp-auth-gateway.service"
        ];
        wants = [ "omp-auth-gateway.service" ];
        wantedBy = [ "multi-user.target" ];

        environment = {
          HOME = stateDir;
          AGENTMEMORY_URL = "http://127.0.0.1:${toString restPort}";
          AGENTMEMORY_VIEWER_URL = "http://127.0.0.1:${toString viewerPort}";
          AGENTMEMORY_ALLOW_AGENT_SDK = "false";
          AGENTMEMORY_AUTO_COMPRESS = "true";
          GRAPH_EXTRACTION_ENABLED = "true";
          CONSOLIDATION_ENABLED = "true";
          AGENTMEMORY_INJECT_CONTEXT = "true";
          AGENTMEMORY_TOOLS = "core";
          AGENTMEMORY_III_VERSION = cfg.package.passthru.iii-engine.version;
          III_REST_PORT = toString restPort;
          III_STREAMS_PORT = toString streamsPort;
          III_STREAM_PORT = toString streamsPort;
          III_VIEWER_PORT = toString viewerPort;
          III_ENGINE_URL = "ws://127.0.0.1:${toString enginePort}";
          VIEWER_ALLOWED_ORIGINS = "http://127.0.0.1:${toString restPort},http://127.0.0.1:${toString viewerPort},http://localhost:${toString restPort},http://localhost:${toString viewerPort}";
        }
        // lib.optionalAttrs cfg.llm.enable {
          OPENAI_BASE_URL = cfg.llm.baseUrl;
          OPENAI_MODEL = cfg.llm.model;
          AGENTMEMORY_LLM_TIMEOUT_MS = toString cfg.llm.timeoutMs;
          OPENAI_TIMEOUT_MS = toString cfg.llm.timeoutMs;
          EMBEDDING_PROVIDER = cfg.llm.embeddingProvider;
        };

        # iii-exec launches configured commands via `sh -c`; keep the
        # service PATH minimal, but include the shell and engine runtime used
        # by Agent Memory's worker process.
        path = [
          pkgs.bash
          pkgs.coreutils
          pkgs.curl
          cfg.package.passthru.iii-engine
        ];

        restartTriggers = [
          iiiConfig
          readyCheck
          startScript
          cfg.package
        ];

        serviceConfig = {
          Type = "simple";
          User = "agentmemory";
          Group = "agentmemory";
          StateDirectory = [
            "agentmemory"
            "agentmemory/data"
          ];
          StateDirectoryMode = "0700";
          WorkingDirectory = stateDir;
          ExecStart = startScript;
          ExecStartPost = readyCheck;
          # iii/Node workers can leave cgroup children behind after the main
          # engine exits. Do not let rebuild/test wait systemd's default 90s
          # stop timeout for a memory observer; SIGKILL cleanup is acceptable
          # after a short graceful drain.
          TimeoutStopSec = "10s";
          Restart = "on-failure";
          RestartSec = "5s";

          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ stateDir ];
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
          ];
        };
      };
    })
  ];
}
