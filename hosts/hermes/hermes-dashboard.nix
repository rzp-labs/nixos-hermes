# Native Hermes dashboard/admin backend for desktop and loopback use.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  hermesCfg = config.services.hermes-agent;
  hermesPackage = hermesCfg.package.override {
    inherit (hermesCfg) extraDependencyGroups extraPythonPackages;
  };
  dashboardHost = "127.0.0.1";
  dashboardPort = 9119;
in
{
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
        }
      ))
    ];

    serviceConfig = {
      Type = "simple";
      User = hermesCfg.user;
      Group = hermesCfg.group;
      WorkingDirectory = hermesCfg.workingDirectory;
      EnvironmentFile = hermesCfg.environmentFiles;
      ExecStart = "${lib.getExe hermesPackage} dashboard --host ${dashboardHost} --port ${toString dashboardPort} --no-open --skip-build";
      ExecStartPost = "${pkgs.curl}/bin/curl --retry 30 --retry-delay 1 --retry-connrefused -fsS http://${dashboardHost}:${toString dashboardPort}/";
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
}
