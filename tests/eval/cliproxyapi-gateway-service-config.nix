# tests/eval/cliproxyapi-gateway-service-config.nix
# Eval check: CLIProxyAPI side-by-side gateway service shape.
#
# Built via: nix build .#checks.x86_64-linux.cliproxyapi-gateway-service-config
{
  pkgs,
  hostConfig,
  hostPkgs,
  ...
}:
let
  unit = hostConfig.systemd.services.cliproxyapi-gateway;
  service = unit.serviceConfig;
  env = unit.environment;
  after = pkgs.lib.toList unit.after;
  wants = pkgs.lib.toList unit.wants;
  tmpfilesRules = hostConfig.systemd.tmpfiles.rules;
  restartTriggers = builtins.concatStringsSep "\n" (map toString unit.restartTriggers);
  execStartPre = builtins.concatStringsSep "\n" (map toString (pkgs.lib.toList service.ExecStartPre));
  execStart = builtins.concatStringsSep "\n" (map toString (pkgs.lib.toList service.ExecStart));
  execStartPost = builtins.concatStringsSep "\n" (
    map toString (pkgs.lib.toList service.ExecStartPost)
  );
  configPath = "/home/admin/.config/cli-proxy-api/config.yaml";
  sopsSecret = hostConfig.sops.secrets.cliproxyapi-key;
in
pkgs.runCommand "cliproxyapi-gateway-service-config" { } ''
  set -eu

  test '${hostPkgs.llm-agents.cli-proxy-api.version}' = '7.1.32'
  test -x '${hostPkgs.llm-agents.cli-proxy-api}/bin/cli-proxy-api'
  ('${hostPkgs.llm-agents.cli-proxy-api}/bin/cli-proxy-api' --version 2>&1 || true) | grep -q -- 'CLIProxyAPI Version: 7.1.32'

  test '${service.Type}' = 'simple'
  test '${service.User}' = 'admin'
  test '${service.WorkingDirectory}' = '/home/admin'
  test '${service.Restart}' = 'on-failure'
  test '${service.RestartSec}' = '5s'
  test '${service.UMask}' = '0077'
  test '${if service.NoNewPrivileges then "true" else "false"}' = 'true'
  test '${builtins.concatStringsSep " " service.RestrictAddressFamilies}' = 'AF_UNIX AF_INET AF_INET6'

  grep -q -- 'network-online.target' <<'EOF'
  ${builtins.concatStringsSep "\n" after}
  EOF
  grep -q -- 'sops-nix.service' <<'EOF'
  ${builtins.concatStringsSep "\n" after}
  EOF
  grep -q -- 'network-online.target' <<'EOF'
  ${builtins.concatStringsSep "\n" wants}
  EOF
  grep -q -- 'sops-nix.service' <<'EOF'
  ${builtins.concatStringsSep "\n" wants}
  EOF

  test '${env.HOME}' = '/home/admin'
  test '${env.XDG_CONFIG_HOME}' = '/home/admin/.config'
  test '${env.XDG_DATA_HOME}' = '/home/admin/.local/share'
  test '${env.XDG_STATE_HOME}' = '/home/admin/.local/state'
  test '${env.XDG_CACHE_HOME}' = '/home/admin/.cache'

  grep -q -- 'd /home/admin/.cli-proxy-api 0700 admin users - -' <<'EOF'
  ${builtins.concatStringsSep "\n" tmpfilesRules}
  EOF
  grep -q -- 'd /home/admin/.config/cli-proxy-api 0700 admin users - -' <<'EOF'
  ${builtins.concatStringsSep "\n" tmpfilesRules}
  EOF

  test -x '${execStartPre}'
  grep -q -- '${sopsSecret.path}' '${execStartPre}'
  grep -q -- '${hostPkgs.yq-go}/bin/yq eval' '${execStartPre}'
  grep -q -- 'strenv(API_KEY)' '${execStartPre}'
  grep -q -- 'cliproxyapi-config.yaml' '${execStartPre}'
  grep -q -- '${configPath}' '${execStartPre}'

  test '${execStart}' = '${hostPkgs.llm-agents.cli-proxy-api}/bin/cli-proxy-api -config ${configPath} -local-model'
  grep -q -- '${hostPkgs.curl}/bin/curl --retry 30 --retry-delay 1 --retry-connrefused -fsS http://127.0.0.1:8317/healthz' <<'EOF'
  ${execStartPost}
  EOF
  grep -q -- '${hostPkgs.llm-agents.cli-proxy-api}' <<'EOF'
  ${restartTriggers}
  EOF
  grep -q -- 'cliproxyapi-config.yaml' <<'EOF'
  ${restartTriggers}
  EOF
  if grep -q -- 'cliproxyapi-gateway-scripts' <<'EOF'
  ${restartTriggers}
  EOF
  then
    echo 'cliproxyapi-gateway should not restart on deleted helper package output' >&2
    exit 1
  fi

  test '${sopsSecret.sopsFile}' = '${../../hosts/hermes/secrets/cliproxyapi-key.enc}'
  test '${sopsSecret.owner}' = 'admin'
  test '${sopsSecret.group}' = 'agentmemory'
  test '${sopsSecret.mode}' = '0440'

  touch $out
''
