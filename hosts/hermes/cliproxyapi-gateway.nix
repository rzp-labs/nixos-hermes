# Host-local CLIProxyAPI sidecar gateway for Hermes inference migration.
{
  config,
  pkgs,
  ...
}:

let
  port = 8317;
  bindHost = "127.0.0.1";
  adminHome = "/home/admin";
  runtimeConfig = "${adminHome}/.config/cli-proxy-api/config.yaml";
  rootUrl = "http://${bindHost}:${toString port}";
  yaml = pkgs.formats.yaml { };

  configFile = yaml.generate "cliproxyapi-config.yaml" {
    host = bindHost;
    inherit port;
    auth-dir = "${adminHome}/.cli-proxy-api";
    api-keys = [ ];
    debug = false;
    logging-to-file = false;
    usage-statistics-enabled = false;
    remote-management = {
      allow-remote = false;
      secret-key = "";
      disable-control-panel = true;
      disable-auto-update-panel = true;
    };
  };
in
{
  systemd.tmpfiles.rules = [
    "d ${adminHome}/.cli-proxy-api 0700 admin users - -"
    "d ${adminHome}/.config/cli-proxy-api 0700 admin users - -"
  ];

  systemd.services.cliproxyapi-gateway = {
    description = "CLIProxyAPI loopback gateway";
    after = [
      "network-online.target"
      "sops-nix.service"
    ];
    wants = [
      "network-online.target"
      "sops-nix.service"
    ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      HOME = adminHome;
      XDG_CONFIG_HOME = "${adminHome}/.config";
      XDG_DATA_HOME = "${adminHome}/.local/share";
      XDG_STATE_HOME = "${adminHome}/.local/state";
      XDG_CACHE_HOME = "${adminHome}/.cache";
    };

    path = [
      pkgs.coreutils
      pkgs.curl
    ];

    restartTriggers = [
      pkgs.llm-agents.cli-proxy-api
      configFile
    ];

    serviceConfig = {
      Type = "simple";
      User = "admin";
      WorkingDirectory = adminHome;
      ExecStartPre = pkgs.writeShellScript "cliproxyapi-gateway-render-config" ''
        set -eu
        API_KEY=$(cat ${config.sops.secrets.cliproxyapi-key.path})
        export API_KEY
        ${pkgs.yq-go}/bin/yq eval '.api-keys = [strenv(API_KEY)]' ${configFile} > ${runtimeConfig}
      '';
      ExecStart = "${pkgs.llm-agents.cli-proxy-api}/bin/cli-proxy-api -config ${runtimeConfig} -local-model";
      ExecStartPost = "${pkgs.curl}/bin/curl --retry 30 --retry-delay 1 --retry-connrefused -fsS ${rootUrl}/healthz";
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
      NoNewPrivileges = true;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
    };
  };
}
