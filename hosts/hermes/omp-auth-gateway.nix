# Host-local inference gateways for Hermes.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  brokerPort = 9000;
  gatewayPort = 4000;
  cliproxyapiPort = 8317;
  bindHost = "127.0.0.1";
  adminHome = "/home/admin";
  tokenFile = "${adminHome}/.omp/auth-broker.token";
  cliproxyapiRuntimeConfig = "${adminHome}/.config/cli-proxy-api/config.yaml";
  omp = lib.getExe pkgs.llm-agents.omp;
  cliproxyapi = lib.getExe pkgs.llm-agents.cli-proxy-api;
  yaml = pkgs.formats.yaml { };

  brokerUrl = "http://${bindHost}:${toString brokerPort}";
  gatewayRootUrl = "http://${bindHost}:${toString gatewayPort}";
  gatewayBaseUrl = "${gatewayRootUrl}/v1";
  cliproxyapiRootUrl = "http://${bindHost}:${toString cliproxyapiPort}";

  adminXdgEnvironment = {
    HOME = adminHome;
    XDG_CONFIG_HOME = "${adminHome}/.config";
    XDG_DATA_HOME = "${adminHome}/.local/share";
    XDG_STATE_HOME = "${adminHome}/.local/state";
    XDG_CACHE_HOME = "${adminHome}/.cache";
  };

  installBrokerToken = pkgs.writeShellScript "omp-auth-broker-install-token" ''
    set -eu
    ${pkgs.coreutils}/bin/install -d -m 0700 -o admin -g users ${adminHome}/.omp
    ${pkgs.coreutils}/bin/install -m 0600 -o admin -g users ${config.sops.secrets.omp-auth-broker-token.path} ${tokenFile}
  '';

  brokerReadyCheck = pkgs.writeShellScript "omp-auth-broker-ready" ''
    set -eu
    token_file=${tokenFile}
    for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
      if [ -r "$token_file" ]; then
        token="$(${pkgs.coreutils}/bin/cat "$token_file")"
        if ${pkgs.curl}/bin/curl -fsS --max-time 2 \
          -H "Authorization: Bearer $token" \
          ${brokerUrl}/v1/healthz >/dev/null; then
          exit 0
        fi
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    echo "OMP auth broker did not become ready" >&2
    exit 1
  '';

  gatewayReadyCheck = pkgs.writeShellScript "omp-auth-gateway-ready" ''
    set -eu
    for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
      if ${pkgs.curl}/bin/curl -fsS --max-time 2 ${gatewayBaseUrl}/models >/dev/null; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    echo "OMP auth gateway did not expose a model catalog" >&2
    exit 1
  '';

  cliproxyapiConfigFile = yaml.generate "cliproxyapi-config.yaml" {
    host = bindHost;
    port = cliproxyapiPort;
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

  renderCliproxyapiConfig = pkgs.writeText "render-cliproxyapi-config.py" ''
    import argparse
    import pathlib
    import sys
    import yaml

    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--api-key-file", required=True)
    args = parser.parse_args()

    config_path = pathlib.Path(args.config)
    api_key = pathlib.Path(args.api_key_file).read_text(encoding="utf-8").strip()
    if not api_key:
        sys.stderr.write("cliproxyapi key file is empty\n")
        sys.exit(1)

    data = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
    data["api-keys"] = [api_key]
    config_path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
  '';

  cliproxyapiSetupScript = pkgs.writeShellScript "cliproxyapi-gateway-setup" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/install -d -m 0700 -o admin -g users ${adminHome}/.cli-proxy-api
    ${pkgs.coreutils}/bin/install -d -m 0700 -o admin -g users ${adminHome}/.config/cli-proxy-api
    ${pkgs.coreutils}/bin/install -m 0600 -o admin -g users ${cliproxyapiConfigFile} ${cliproxyapiRuntimeConfig}
  '';

  cliproxyapiStartScript = pkgs.writeShellScript "cliproxyapi-gateway-start" ''
    set -euo pipefail
    ${
      pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pyyaml ])
    }/bin/python ${renderCliproxyapiConfig} \
      --config ${cliproxyapiRuntimeConfig} \
      --api-key-file ${config.sops.secrets.cliproxyapi-key.path}
    exec ${cliproxyapi} -config ${cliproxyapiRuntimeConfig} -local-model
  '';

  cliproxyapiReadyCheck = pkgs.writeShellScript "cliproxyapi-gateway-ready" ''
    set -eu
    for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
      if ${pkgs.curl}/bin/curl -fsS --max-time 2 ${cliproxyapiRootUrl}/healthz >/dev/null; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    echo "CLIProxyAPI gateway did not become healthy" >&2
    exit 1
  '';
in
{
  services.hermes-agent = {
    settings = {
      model = {
        # Keep Hermes on the proven OMP loopback gateway until the side-by-side
        # CLIProxyAPI service has a populated auth directory and parity smokes.
        provider = "custom";
        default = "gpt-5.5";
        base_url = gatewayBaseUrl;
        api_mode = "codex_responses";
        openai_runtime = "auto";
      };

      fallback_model = {
        # Keep fallback behind the same local gateway, but route it to a
        # different upstream provider/model so OpenAI OAuth exhaustion does not
        # take out both primary and failover. Clear api_mode here so Hermes
        # does not reuse the primary Codex Responses shaping for Antigravity.
        provider = "custom";
        base_url = gatewayBaseUrl;
        model = "gemini-3-flash-agent:high";
        api_mode = "";
      };
    };
  };

  systemd.services = {
    cliproxyapi-gateway = {
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

      environment = adminXdgEnvironment;

      path = [
        pkgs.coreutils
        pkgs.curl
        pkgs.python3
        pkgs.llm-agents.cli-proxy-api
      ];

      restartTriggers = [
        pkgs.llm-agents.cli-proxy-api
        cliproxyapiConfigFile
        cliproxyapiReadyCheck
        cliproxyapiSetupScript
        cliproxyapiStartScript
        renderCliproxyapiConfig
      ];

      serviceConfig = {
        Type = "simple";
        User = "admin";
        WorkingDirectory = adminHome;
        ExecStartPre = "+${cliproxyapiSetupScript}";
        ExecStart = cliproxyapiStartScript;
        ExecStartPost = cliproxyapiReadyCheck;
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

    omp-auth-broker = {
      description = "OMP OAuth auth broker";
      after = [
        "network-online.target"
        "sops-nix.service"
      ];
      wants = [
        "network-online.target"
        "sops-nix.service"
      ];
      wantedBy = [ "multi-user.target" ];

      environment = adminXdgEnvironment;

      path = [
        pkgs.coreutils
        pkgs.curl
      ];

      restartTriggers = [
        pkgs.llm-agents.omp
        brokerReadyCheck
        installBrokerToken
      ];

      serviceConfig = {
        Type = "simple";
        User = "admin";
        WorkingDirectory = adminHome;
        ExecStartPre = "+${installBrokerToken}";
        ExecStart = "${omp} auth-broker serve --bind=${bindHost}:${toString brokerPort}";
        ExecStartPost = brokerReadyCheck;
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

    omp-auth-gateway = {
      description = "OMP loopback auth gateway";
      after = [
        "network-online.target"
        "omp-auth-broker.service"
      ];
      requires = [ "omp-auth-broker.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = adminXdgEnvironment // {
        OMP_AUTH_BROKER_URL = brokerUrl;
      };

      path = [
        pkgs.coreutils
        pkgs.curl
      ];

      restartTriggers = [
        pkgs.llm-agents.omp
        gatewayReadyCheck
      ];

      serviceConfig = {
        Type = "simple";
        User = "admin";
        WorkingDirectory = adminHome;
        ExecStart = "${omp} auth-gateway serve --bind=${bindHost}:${toString gatewayPort} --no-auth";
        ExecStartPost = gatewayReadyCheck;
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

    hermes-agent = {
      after = [ "omp-auth-gateway.service" ];
      requires = [ "omp-auth-gateway.service" ];
    };
  };
}
