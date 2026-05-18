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

      passthru = previousAttrs.passthru // {
        nd-mcp =
          (pkgs.buildGoModule {
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
              description = "Netdata Model Context Protocol (MCP) Integration";
              license = lib.licenses.gpl3Only;
            };
          }).goModules;

        netdata-go-modules =
          (pkgs.buildGoModule {
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
          }).goModules;
      };

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
      token="$(awk -F= '/^[[:space:]]*token[[:space:]]*=/{ sub(/^[[:space:]]*/, "", $2); print $2 }' "$claim_conf")"
      url="$(awk -F= '/^[[:space:]]*url[[:space:]]*=/{ sub(/^[[:space:]]*/, "", $2); print $2 }' "$claim_conf")"
      rooms="$(awk -F= '/^[[:space:]]*rooms[[:space:]]*=/{ sub(/^[[:space:]]*/, "", $2); print $2 }' "$claim_conf")"

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

  netdataGoPluginConfig = pkgs.writeText "netdata-go.d.conf" ''
    enabled: yes
    default_run: yes

    modules:
      # This host runs PostgreSQL for local services, but Netdata autodiscovery
      # cannot authenticate to it by default and spams the journal with failed
      # probe attempts. Keep process/systemd-level PostgreSQL visibility from
      # apps/systemd collectors, but disable the DB-specific go.d collector until
      # explicit DB credentials/role are intentionally provisioned.
      postgres: no
      pgbouncer: no
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
          get "/api/v1/data?chart=$chart&after=-$seconds&format=json"
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

      "go.d.conf" = netdataGoPluginConfig;
    };
  };

  environment.systemPackages = [
    netdataPackage
    netdataObserve
  ];

  systemd.services.netdata.serviceConfig = {
    LoadCredential = [
      "netdata_claim_conf:${config.sops.secrets.netdata-claim-conf.path}"
    ];
    ExecStartPre = "+${pkgs.writeShellScript "netdata-install-cloud-claim-conf" ''
      set -euo pipefail
      install -D -o root -g netdata -m 0640 \
        "$CREDENTIALS_DIRECTORY/netdata_claim_conf" \
        /etc/netdata/claim.conf
    ''}";
    ExecStartPost = lib.mkForce [
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
