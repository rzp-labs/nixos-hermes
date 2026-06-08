# Reusable native Hermes dashboard/admin backend service.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.hermes-dashboard;
  hermesCfg = config.services.hermes-agent;
  hermesPackage = hermesCfg.package.override {
    inherit (hermesCfg) extraDependencyGroups extraPythonPackages;
  };
  dashboardUrl = "http://${cfg.host}:${toString cfg.port}/";
in
{
  options.services.hermes-dashboard = {
    enable = lib.mkEnableOption "the native Hermes dashboard/admin backend";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address the Hermes dashboard should bind to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9119;
      description = "TCP port the Hermes dashboard should listen on.";
    };

    skipBuild = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use the packaged Hermes web distribution instead of building frontend assets at service start.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.hermes-dashboard = {
      description = "Hermes native dashboard";
      after = [
        "network.target"
        "hermes-agent.service"
      ];
      wants = [ "hermes-agent.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = hermesCfg.environment // {
        HERMES_HOME = "${hermesCfg.stateDir}/.hermes";
        HERMES_MANAGED = "true";
        HOME = hermesCfg.stateDir;
        HERMES_WEB_DIST = "${hermesPackage}/share/hermes-agent/web_dist";
      };

      path = config.systemd.services.hermes-agent.path or [ ];

      restartTriggers = [
        hermesPackage
        (pkgs.writeText "hermes-dashboard-runtime-config-trigger.json" (
          builtins.toJSON {
            settings = hermesCfg.settings;
            mcpServers = hermesCfg.mcpServers;
            extraPlugins = map toString hermesCfg.extraPlugins;
            webDist = "${hermesPackage}/share/hermes-agent/web_dist";
            dashboard = {
              inherit (cfg) host port skipBuild;
            };
          }
        ))
      ];

      serviceConfig = {
        Type = "simple";
        User = hermesCfg.user;
        Group = hermesCfg.group;
        WorkingDirectory = hermesCfg.workingDirectory;
        EnvironmentFile = hermesCfg.environmentFiles;
        ExecStart = lib.concatStringsSep " " (
          [
            (lib.getExe hermesPackage)
            "dashboard"
            "--host"
            cfg.host
            "--port"
            (toString cfg.port)
            "--no-open"
          ]
          ++ lib.optionals cfg.skipBuild [ "--skip-build" ]
        );
        ExecStartPost = "${pkgs.curl}/bin/curl --retry 30 --retry-delay 1 --retry-connrefused -fsS ${dashboardUrl}";
        Restart = "always";
        RestartSec = "5s";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = false;
        ProtectSystem = "strict";
        ReadWritePaths = [
          hermesCfg.stateDir
          hermesCfg.workingDirectory
        ];
        TimeoutStopSec = 30;
        UMask = "0007";
      };
    };
  };
}
