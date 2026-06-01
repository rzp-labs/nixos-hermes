# Host-local OMP auth broker/gateway for Hermes inference.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  brokerPort = 9000;
  gatewayPort = 4000;
  bindHost = "127.0.0.1";
  adminHome = "/home/admin";
  tokenFile = "${adminHome}/.omp/auth-broker.token";
  omp = lib.getExe pkgs.llm-agents.omp;

  brokerUrl = "http://${bindHost}:${toString brokerPort}";
  gatewayBaseUrl = "http://${bindHost}:${toString gatewayPort}/v1";
  cliProxyApiBaseUrl = "http://${bindHost}:8317/v1";

  adminXdgEnvironment = {
    HOME = adminHome;
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
in
{
  services.hermes-agent = {
    settings = {
      model = {
        # Route Hermes through the CLIProxyAPI loopback gateway for the primary
        # Codex Responses path. Use a named custom provider so Hermes reads the
        # configured API key; bare provider=custom falls back to no-key-required
        # on loopback endpoints, which CLIProxyAPI correctly rejects.
        provider = "custom:cliproxyapi";
        default = "gpt-5.5";
        base_url = cliProxyApiBaseUrl;
        api_mode = "codex_responses";
        openai_runtime = "auto";
      };

      custom_providers = [
        {
          name = "cliproxyapi";
          base_url = cliProxyApiBaseUrl;
          api_key = "\${CLIPROXYAPI_KEY}";
          api_mode = "codex_responses";
          model = "gpt-5.5";
        }
      ];

      fallback_model = {
        # Keep OMP auth-gateway as the fallback while CLIProxyAPI is promoted to
        # primary. Clear api_mode here so Hermes does not reuse the primary
        # Codex Responses shaping for the Antigravity/Gemini fallback route.
        provider = "custom";
        base_url = gatewayBaseUrl;
        model = "gemini-3-flash-agent:high";
        api_mode = "";
      };
    };
  };

  systemd.services = {
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
