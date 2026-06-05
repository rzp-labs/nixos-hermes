# tests/eval/netdata-service-config.nix
# Eval check: Netdata service config + observe wrapper + Hermes MCP wiring.
#
# Pure-evaluation assertion derivation extracted from flake.nix.
# Built via: nix build .#checks.x86_64-linux.netdata-service-config
{ pkgs, hostConfig, ... }:
let
  netdataCfg = hostConfig.services.netdata;
  netdataUnit = hostConfig.systemd.services.netdata;
  hermesSupplementaryGroups = pkgs.lib.toList hostConfig.systemd.services.hermes-agent.serviceConfig.SupplementaryGroups;
  hermesUserGroups = pkgs.lib.toList hostConfig.users.users.hermes.extraGroups;
  netdataObservePackage = builtins.head (
    builtins.filter (
      pkg: pkgs.lib.getName pkg == "netdata-observe"
    ) hostConfig.environment.systemPackages
  );
  systemPackages = builtins.map (pkg: pkgs.lib.getName pkg) hostConfig.environment.systemPackages;
  netdataLoadCredentials = pkgs.lib.toList netdataUnit.serviceConfig.LoadCredential;
  netdataExecStartPost = pkgs.lib.toList netdataUnit.serviceConfig.ExecStartPost;
  netdataSupplementaryGroups = pkgs.lib.toList netdataUnit.serviceConfig.SupplementaryGroups;
  hermesNetdataMcp = hostConfig.services.hermes-agent.mcpServers.netdata;
  serviceNames = builtins.attrNames hostConfig.systemd.services;
  netdataConfigDirNames = builtins.attrNames netdataCfg.configDir;
in
pkgs.runCommand "netdata-service-config" { } ''
  set -eu
  test '${if netdataCfg.enable then "true" else "false"}' = 'true'
  test '${netdataCfg.package.version}' = '2.10.3'
  test '${if netdataCfg.enableAnalyticsReporting then "true" else "false"}' = 'false'
  test '${netdataCfg.config.web."bind to"}' = '127.0.0.1'
  test '${netdataCfg.config.plugins.freeipmi}' = 'no'
  test '${netdataCfg.config.plugins."logs-management"}' = 'no'
  test '${toString (builtins.elem "systemd-journal" netdataSupplementaryGroups)}' = '1'
  test '${hostConfig.sops.secrets.netdata-claim-conf.sopsFile}' = '${../../den/hosts/nixos-hermes/secrets/payload/netdata-claim.conf}'
  test '${toString (builtins.elem "netdata_claim_conf:${hostConfig.sops.secrets.netdata-claim-conf.path}" netdataLoadCredentials)}' = '1'
  grep -q -- 'netdata-install-cloud-claim-conf' <<'EOF'
  ${builtins.toString netdataUnit.serviceConfig.ExecStartPre}
  EOF
  grep -q -- 'netdata-cloud-claim' <<'EOF'
  ${builtins.toString netdataExecStartPost}
  EOF
  test '${toString (builtins.elem "netdata-observe" systemPackages)}' = '1'
  grep -q -- '/bin/nd-mcp-bridge' <<'EOF'
  ${hermesNetdataMcp.command}
  EOF
  test '${builtins.concatStringsSep " " hermesNetdataMcp.args}' = 'ws://127.0.0.1:19999/mcp'
  test '${toString (builtins.elem "systemd-journal" hermesSupplementaryGroups)}' = '1'
  test '${toString (builtins.elem "systemd-journal" hermesUserGroups)}' = '1'
  '${netdataObservePackage}/bin/netdata-observe' --help | grep -q -- 'logs \[unit\] \[lines\]'
  grep -q -- 'arbitrary journalctl arguments are not allowed' '${netdataObservePackage}/bin/netdata-observe'
  grep -q -- 'netdata.service|hermes-agent.service|agentmemory.service|hindsight-embed.service|omp-auth-gateway.service' '${netdataObservePackage}/bin/netdata-observe'
  grep -q -- '--output=short-iso' '${netdataObservePackage}/bin/netdata-observe'
  grep -q -- '10#$lines' '${netdataObservePackage}/bin/netdata-observe'
  '${netdataObservePackage}/bin/netdata-observe' logs netdata.service 08 >/dev/null
  ! '${netdataObservePackage}/bin/netdata-observe' logs sshd.service 10 2>/dev/null
  ! '${netdataObservePackage}/bin/netdata-observe' logs netdata.service 501 2>/dev/null
  ! '${netdataObservePackage}/bin/netdata-observe' logs netdata.service 10 --since=-1h 2>/dev/null
  test -d '${hostConfig.environment.etc."netdata/conf.d".source}/scripts.d'
  test -f '${hostConfig.environment.etc."netdata/conf.d".source}/scripts.d/nagios.conf'
  test '${if hostConfig.services.postgresql.enable then "true" else "false"}' = 'false'
  test '${
    if builtins.elem "go.d/postgres.conf" netdataConfigDirNames then "true" else "false"
  }' = 'false'
  test '${
    if builtins.elem "netdata-postgres-monitoring-setup" serviceNames then "true" else "false"
  }' = 'false'
  grep -q -- '127.0.0.1' '${hostConfig.environment.etc."netdata/netdata.conf".source}'
  grep -q -- '-D -c /etc/netdata/netdata.conf' <<'EOF'
  ${netdataUnit.serviceConfig.ExecStart}
  EOF
  touch $out
''
