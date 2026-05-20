# Netdata Cloud agent plus a native CLI for Hermes access to metrics/logs.
{
  config,
  lib,
  nixpkgs-llama,
  pkgs,
  ...
}:

let
  netdataPackageBase = nixpkgs-llama.legacyPackages.${pkgs.stdenv.hostPlatform.system}.netdata;

  # Netdata Cloud currently requires 2.10.2 for security fixes, while both the
  # primary FlakeHub nixpkgs input and nixpkgs-llama still package older agents.
  # Keep this scoped to the Netdata package; do not move the host to NixOS stable.
  netdataPackage = netdataPackageBase.overrideAttrs (
    finalAttrs: previousAttrs: {
      version = "2.10.2";

      src = pkgs.fetchFromGitHub {
        owner = "netdata";
        repo = "netdata";
        rev = "v${finalAttrs.version}";
        hash = "sha256-TSjvQYBcLDMXYGa43g3RG43cM2aPBem/d/EJu9o97yQ=";
        fetchSubmodules = true;
      };

      passthru =
        previousAttrs.passthru
        // (
          let
            ndMcpBridge = pkgs.buildGoModule {
              pname = "${finalAttrs.pname}-nd-mcp";
              inherit (finalAttrs) version src;
              sourceRoot = "${finalAttrs.src.name}/src/web/mcp/bridges/stdio-golang";
              vendorHash = "sha256-jyCTp52Dc2IuRwzGT+sHFljO30oqAMfe3xVdEpV+R2c=";
              proxyVendor = true;
              doCheck = false;
              subPackages = [ "." ];
              ldflags = [
                "-s"
                "-w"
              ];
              meta = finalAttrs.meta // {
                description = "Netdata Model Context Protocol (MCP) stdio bridge";
                mainProgram = "nd-mcp-bridge";
                license = lib.licenses.gpl3Only;
              };
            };
            goPlugin = pkgs.buildGoModule {
              pname = "${finalAttrs.pname}-go-plugins";
              inherit (finalAttrs) version src;
              sourceRoot = "${finalAttrs.src.name}/src/go/plugin/go.d";
              vendorHash = "sha256-HRe1bcVIQVzwPZnGlAK5A8AO1VTcjFajkPwBVdl4UIA=";
              proxyVendor = true;
              doCheck = false;
              ldflags = [
                "-s"
                "-w"
                "-X main.version=${finalAttrs.version}"
              ];
              meta = finalAttrs.meta // {
                description = "Netdata orchestrator for data collection modules written in Go";
                mainProgram = "godplugin";
                license = lib.licenses.gpl3Only;
              };
            };
          in
          {
            # These attr names are consumed by the upstream Netdata CMake build as
            # file:// GOPROXY inputs, so they must stay as module proxy trees.
            nd-mcp = ndMcpBridge.goModules;
            netdata-go-modules = goPlugin.goModules;

            # Export the runnable packages separately for host/Hermes usage.
            nd-mcp-bridge = ndMcpBridge;
            netdata-go-plugin = goPlugin;
          }
        );

      cargoRoot = "src/crates";
      cargoDeps = pkgs.symlinkJoin {
        name = "cargo-vendor-dir";
        paths = [
          (pkgs.rustPlatform.fetchCargoVendor {
            inherit (finalAttrs)
              pname
              version
              src
              cargoRoot
              ;
            hash = "sha256-mxFpT95e+NMqjJOIRqM+yKHGQHfpWmIFHqFNiiiqXOY=";
          })
          (pkgs.rustPlatform.fetchCargoVendor {
            pname = "${finalAttrs.pname}-nd-jf";
            inherit (finalAttrs) version src;
            cargoRoot = "${finalAttrs.cargoRoot}/jf";
            hash = "sha256-6spr8WRt2G6tzaUQACxIcVMoDNKOFTg6rSPEOihMgLE=";
          })
        ];
      };
    }
  );

  # Local Netdata agent API endpoint consumed by netdata-observe. This is not
  # the operator dashboard; Netdata Cloud is the dashboard/control plane.
  netdataAgentApiUrl = "http://127.0.0.1:19999";

  netdataWaitForApi = pkgs.writeShellScript "wait-for-netdata-up" ''
    until [ "$(${netdataPackage}/bin/netdatacli ping)" = pong ]; do
      sleep 0.5
    done
  '';

  netdataCloudClaim = pkgs.writeShellApplication {
    name = "netdata-cloud-claim";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.gawk
    ];
    text = ''
      set -euo pipefail

      base_url="${netdataAgentApiUrl}"
      claim_conf="$CREDENTIALS_DIRECTORY/netdata_claim_conf"
      session_key_file="/var/lib/netdata/netdata_random_session_id"

      status="$(curl --fail --silent --show-error "$base_url/api/v3/claim" | jq -r '.cloud.status')"
      if [[ "$status" == "online" ]]; then
        exit 0
      fi

      if [[ ! -r "$session_key_file" ]]; then
        echo "Netdata claim session key is not readable: $session_key_file" >&2
        exit 1
      fi

      key="$(< "$session_key_file")"
      token="$(awk -F= '/^[[:space:]]*token[[:space:]]*=/{ sub(/^[[:space:]]*/, "", $2); print $2; exit }' "$claim_conf")"
      url="$(awk -F= '/^[[:space:]]*url[[:space:]]*=/{ sub(/^[[:space:]]*/, "", $2); print $2; exit }' "$claim_conf")"
      rooms="$(awk -F= '/^[[:space:]]*rooms[[:space:]]*=/{ sub(/^[[:space:]]*/, "", $2); print $2; exit }' "$claim_conf")"

      if [[ -z "$token" || -z "$url" ]]; then
        echo "Netdata claim configuration is missing token or url" >&2
        exit 1
      fi

      query="key=$(jq -rn --arg v "$key" '$v|@uri')&token=$(jq -rn --arg v "$token" '$v|@uri')&url=$(jq -rn --arg v "$url" '$v|@uri')"
      if [[ -n "$rooms" ]]; then
        query="$query&rooms=$(jq -rn --arg v "$rooms" '$v|@uri')"
      fi

      result="$(curl --fail --silent --show-error "$base_url/api/v3/claim?$query")"
      success="$(jq -r '.success // false' <<<"$result")"
      cloud_status="$(jq -r '.cloud.status // "unknown"' <<<"$result")"
      if [[ "$success" != "true" && "$cloud_status" != "online" ]]; then
        jq . <<<"$result" >&2
        exit 1
      fi
    '';
  };

  netdataPostgresConfig = pkgs.writeText "netdata-postgres.conf" ''
    # Netdata's documented PostgreSQL setup is a local `netdata` database role
    # with pg_monitor (or pg_read_all_stats), then a file-managed go.d job.
    # Use peer auth over the local Unix socket; no SOPS password is needed for
    # this host-local collector.
    update_every: 1
    autodetection_retry: 60
    jobs:
      - name: local
        dsn: 'host=/var/run/postgresql dbname=postgres user=netdata'
        collect_databases_matching: '*'
  '';

  netdataObserve = pkgs.writeShellApplication {
    name = "netdata-observe";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail

      base_url="''${NETDATA_AGENT_API_URL:-${netdataAgentApiUrl}}"

      usage() {
        cat <<'EOF'
      Usage: netdata-observe <command> [args]

      Commands:
        info                         Show Netdata agent info
        alarms                       Show active alarms
        charts                       List available charts
        allmetrics                   Dump all metrics as JSON
        data <chart> [seconds]       Fetch chart data, default window: 300s
        api <path-or-url>            Call an arbitrary Netdata API path
        logs [unit] [journal args]   Show systemd logs, default unit: netdata.service

      Examples:
        netdata-observe data system.cpu 600
        netdata-observe api /api/v1/data?chart=system.ram\&after=-300\&format=json
        netdata-observe logs netdata.service -n 200 --no-pager
      EOF
      }

      get() {
        local target="$1"
        if [[ "$target" == http://* || "$target" == https://* ]]; then
          curl --fail --silent --show-error "$target" | jq .
        else
          [[ "$target" == /* ]] || target="/$target"
          curl --fail --silent --show-error "$base_url$target" | jq .
        fi
      }

      command="''${1:-}"
      if [[ -z "$command" ]]; then
        usage
        exit 2
      fi
      shift

      case "$command" in
        info)
          get /api/v1/info
          ;;
        alarms)
          get /api/v1/alarms
          ;;
        charts)
          get /api/v1/charts
          ;;
        allmetrics)
          get /api/v1/allmetrics?format=json
          ;;
        data)
          chart="''${1:-}"
          seconds="''${2:-300}"
          if [[ -z "$chart" ]]; then
            echo "chart is required" >&2
            usage >&2
            exit 2
          fi
          chart_encoded=$(jq -rn --arg v "$chart" '$v|@uri')
          get "/api/v1/data?chart=$chart_encoded&after=-$seconds&format=json"
          ;;
        api)
          target="''${1:-}"
          if [[ -z "$target" ]]; then
            echo "API path or URL is required" >&2
            usage >&2
            exit 2
          fi
          get "$target"
          ;;
        logs)
          unit="''${1:-netdata.service}"
          if [[ $# -gt 0 ]]; then
            shift
          fi
          journalctl -u "$unit" "$@"
          ;;
        -h|--help|help)
          usage
          ;;
        *)
          echo "unknown command: $command" >&2
          usage >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  services.netdata = {
    enable = true;

    # Use the current Netdata stable release without pinning this host to a
    # NixOS/nixpkgs stable channel.
    package = netdataPackage;

    enableAnalyticsReporting = false;

    config = {
      plugins = {
        # This host has no IPMI/BMC hardware; out-of-band management is AMT/vPro.
        # Disable the enterprise-server hardware collector instead of letting it
        # emit recurring FreeIPMI internal errors.
        freeipmi = "no";

        # The Nix package exposes systemd-journal/OTel log functions, but does
        # not ship logs-management.plugin. Without this explicit disable, the
        # generated setuid wrapper directory advertises a missing plugin and
        # Netdata logs an exit-127 collector failure on every restart.
        "logs-management" = "no";
      };

      web = {
        # No local dashboard exposure: Netdata Cloud is the operator UI. Keep
        # the host API loopback-only for diagnostics and netdata-observe.
        "bind to" = "127.0.0.1";
      };
    };

    configDir = {
      # Netdata's scripts.d plugin watches this directory even when no jobs are
      # configured. The NixOS module renders /etc/netdata/conf.d from only
      # configDir entries, so expose the packaged empty/example directory to
      # avoid one journal error per minute about a missing path.
      "scripts.d" = "${netdataPackage}/share/netdata/conf.d/scripts.d";
    }
    // lib.optionalAttrs config.services.postgresql.enable {
      "go.d/postgres.conf" = netdataPostgresConfig;
    };
  };

  services.hermes-agent.mcpServers.netdata = {
    command = lib.getExe netdataPackage.passthru.nd-mcp-bridge;
    args = [ "ws://127.0.0.1:19999/mcp" ];
  };

  services.postgresql.ensureUsers = lib.mkIf config.services.postgresql.enable [
    {
      name = "netdata";
    }
  ];

  systemd.services.netdata-postgres-monitoring-setup = lib.mkIf config.services.postgresql.enable {
    description = "Grant PostgreSQL monitoring privileges to Netdata";
    wantedBy = [ "multi-user.target" ];
    after = [
      "postgresql.service"
      "postgresql-setup.service"
    ];
    requires = [
      "postgresql.service"
      "postgresql-setup.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      Group = "postgres";
      ExecStart = "${config.services.postgresql.package}/bin/psql -d postgres -tAc 'GRANT pg_monitor TO netdata;'";
    };
  };

  environment.systemPackages = [
    netdataPackage
    netdataObserve
  ];

  systemd.services.netdata.serviceConfig = {
    SupplementaryGroups = [
      # Netdata Cloud's systemd-journal function is served by the Netdata agent,
      # not by Hermes. Grant the agent read-only journal group access so log
      # exploration works without exposing the local dashboard beyond loopback.
      "systemd-journal"
    ];
    LoadCredential = [
      "netdata_claim_conf:${config.sops.secrets.netdata-claim-conf.path}"
    ];
    ExecStartPre = "+${pkgs.writeShellScript "netdata-install-cloud-claim-conf" ''
      set -euo pipefail
      install -D -o root -g netdata -m 0640 \
        "$CREDENTIALS_DIRECTORY/netdata_claim_conf" \
        /etc/netdata/claim.conf
    ''}";
    ExecStartPost = [
      "${netdataWaitForApi}"
      "+${lib.getExe netdataCloudClaim}"
    ];
  };

  systemd.services.hermes-agent.serviceConfig.SupplementaryGroups = [
    # Tool calls run under hermes-agent.service. Grant the service read-only
    # journal access for netdata-observe logs without making Netdata a startup
    # dependency of Hermes or making journal access a general property of every
    # hermes login/session.
    "systemd-journal"
  ];
}
