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
  dashboardHealthHostRaw =
    if cfg.host == "0.0.0.0" then
      "127.0.0.1"
    else if cfg.host == "::" then
      "::1"
    else
      cfg.host;
  dashboardHealthHost =
    if
      builtins.match ".*:.*" dashboardHealthHostRaw != null && !lib.hasPrefix "[" dashboardHealthHostRaw
    then
      "[${dashboardHealthHostRaw}]"
    else
      dashboardHealthHostRaw;
  dashboardUrl = "http://${dashboardHealthHost}:${toString cfg.port}/";
  readinessTimeoutSec = if cfg.skipBuild then 30 else 300;
  timeoutStartSec = if cfg.skipBuild then 90 else 360;
  readyCheck = pkgs.writeShellScript "hermes-dashboard-ready-check" ''
    deadline=$((SECONDS + ${toString readinessTimeoutSec}))
    while [ "$SECONDS" -le "$deadline" ]; do
      if ${pkgs.curl}/bin/curl --max-time 2 -fsS ${lib.escapeShellArg dashboardUrl} >/dev/null; then
        exit 0
      fi
      sleep 1
    done

    echo "Hermes dashboard did not become ready within ${toString readinessTimeoutSec}s" >&2
    exit 1
  '';
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
        ExecStartPost = readyCheck;
        Restart = "always";
        RestartSec = "5s";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = false;
        ProtectSystem = "strict";
        ReadWritePaths = lib.filter (path: path != null) [
          hermesCfg.stateDir
          hermesCfg.workingDirectory
        ];
        TimeoutStartSec = timeoutStartSec;
        TimeoutStopSec = 30;
        UMask = "0007";
      };
    };
  };
}
