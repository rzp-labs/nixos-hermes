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
  viewerPort = 3113;
  enginePort = 49134;
  yaml = pkgs.formats.yaml { };
  agentmemoryRoot = "${cfg.package}/lib/node_modules/@agentmemory/agentmemory";
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
        config.adapter.name = "kv";
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
in
{
  options.services.agentmemory = {
    enable = lib.mkEnableOption "Agent Memory local parallel-observer service";

    package = lib.mkPackageOption pkgs "agentmemory" { };
  };

  config = lib.mkMerge [
    {
      services.agentmemory.enable = lib.mkDefault true;
    }

    (lib.mkIf cfg.enable {
      users.users.agentmemory = {
        isSystemUser = true;
        group = "agentmemory";
        home = stateDir;
        createHome = false;
      };

      users.groups.agentmemory = { };

      systemd.services.agentmemory = {
        description = "Agent Memory parallel observer";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        environment = {
          HOME = stateDir;
          AGENTMEMORY_URL = "http://127.0.0.1:${toString restPort}";
          AGENTMEMORY_VIEWER_URL = "http://127.0.0.1:${toString viewerPort}";
          AGENTMEMORY_ALLOW_AGENT_SDK = "false";
          AGENTMEMORY_AUTO_COMPRESS = "false";
          GRAPH_EXTRACTION_ENABLED = "false";
          CONSOLIDATION_ENABLED = "false";
          AGENTMEMORY_INJECT_CONTEXT = "false";
          AGENTMEMORY_TOOLS = "core";
          AGENTMEMORY_III_VERSION = cfg.package.passthru.iii-engine.version;
          III_REST_PORT = toString restPort;
          III_STREAMS_PORT = toString streamsPort;
          III_STREAM_PORT = toString streamsPort;
          III_VIEWER_PORT = toString viewerPort;
          III_ENGINE_URL = "ws://127.0.0.1:${toString enginePort}";
          VIEWER_ALLOWED_ORIGINS = "http://127.0.0.1:${toString restPort},http://127.0.0.1:${toString viewerPort},http://localhost:${toString restPort},http://localhost:${toString viewerPort}";
        };

        # iii-exec launches configured commands via `sh -c`; keep the
        # service PATH minimal, but include the shell and engine runtime used
        # by Agent Memory's worker process.
        path = [
          pkgs.bash
          pkgs.coreutils
          cfg.package.passthru.iii-engine
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
          ExecStart = "${lib.getExe cfg.package.passthru.iii-engine} --config ${iiiConfig}";
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
