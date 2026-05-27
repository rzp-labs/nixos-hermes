# Host-local OMP auth broker/gateway for Hermes inference.
{ lib, pkgs, ... }:

let
  brokerPort = 9000;
  gatewayPort = 4000;
  bindHost = "127.0.0.1";
  adminHome = "/home/admin";
  omp = lib.getExe pkgs.llm-agents.omp;

  brokerUrl = "http://${bindHost}:${toString brokerPort}";
  gatewayBaseUrl = "http://${bindHost}:${toString gatewayPort}/v1";

  brokerReadyCheck = pkgs.writeShellScript "omp-auth-broker-ready" ''
    set -eu
    token_file=${adminHome}/.omp/auth-broker.token
    for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
      if [ -r "$token_file" ]; then
        token="$(${pkgs.coreutils}/bin/cat "$token_file")"
        if ${pkgs.curl}/bin/curl -fsS --max-time 2 \
          -H "Authorization: Bearer $token" \
          ${brokerUrl}/v1/healthz >/dev/null; then
          exit 0
        fi
      fi
      sleep 1
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
      sleep 1
    done
    echo "OMP auth gateway did not expose a model catalog" >&2
    exit 1
  '';
in
{
  services.hermes-agent = {
    settings = {
      model = {
        # Route Hermes through OMP's loopback auth-gateway so OMP owns OAuth
        # refresh and provider-specific Codex request shaping. Do not use the
        # Hermes openai-codex provider here: Hermes 0.14 resolves that provider
        # through its own ChatGPT OAuth credential pool and ignores model.base_url.
        provider = "custom";
        default = "gpt-5.5";
        base_url = gatewayBaseUrl;
        api_mode = "codex_responses";
        openai_runtime = "auto";
      };

      fallback_model = {
        provider = "custom";
        base_url = gatewayBaseUrl;
        model = "gpt-5.5";
      };
    };
  };

  systemd.services = {
    omp-auth-broker = {
      description = "OMP OAuth auth broker";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOME = adminHome;
      };

      path = [
        pkgs.coreutils
        pkgs.curl
      ];

      restartTriggers = [
        pkgs.llm-agents.omp
        brokerReadyCheck
      ];

      serviceConfig = {
        Type = "simple";
        User = "admin";
        WorkingDirectory = adminHome;
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

      environment = {
        HOME = adminHome;
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
