# tests/eval/hermes-dashboard-service-config.nix
# Eval check: native Hermes dashboard service wiring.
#
# Built via: nix build .#checks.x86_64-linux.hermes-dashboard-service-config
{ pkgs, hostConfig, ... }:
let
  unit = hostConfig.systemd.services.hermes-dashboard;
  service = unit.serviceConfig;
  env = unit.environment;
  hermesCfg = hostConfig.services.hermes-agent;
  hermesPackage = hermesCfg.package.override {
    inherit (hermesCfg) extraDependencyGroups extraPythonPackages;
  };
  serviceNames = builtins.attrNames hostConfig.systemd.services;
in
pkgs.runCommand "hermes-dashboard-service-config" { } ''
  set -eu
  test '${if builtins.elem "hermes-dashboard" serviceNames then "true" else "false"}' = 'true'
  test '${if builtins.elem "hermes-webui" serviceNames then "true" else "false"}' = 'false'
  test '${service.User}' = '${hermesCfg.user}'
  test '${service.Group}' = '${hermesCfg.group}'
  test '${service.WorkingDirectory}' = '${hermesCfg.workingDirectory}'
  test '${env.HERMES_HOME}' = '${hermesCfg.stateDir}/.hermes'
  test '${env.HERMES_MANAGED}' = 'true'
  test '${env.HOME}' = '${hermesCfg.stateDir}'
  test '${env.HERMES_WEB_DIST}' = '${hermesPackage}/share/hermes-agent/web_dist'
  test -f '${hermesPackage}/share/hermes-agent/web_dist/index.html'
  grep -q -- '/bin/hermes dashboard' <<'EOF'
  ${service.ExecStart}
  EOF
  grep -q -- '--host 127.0.0.1' <<'EOF'
  ${service.ExecStart}
  EOF
  grep -q -- '--port 9119' <<'EOF'
  ${service.ExecStart}
  EOF
  grep -q -- '--no-open' <<'EOF'
  ${service.ExecStart}
  EOF
  grep -q -- '--skip-build' <<'EOF'
  ${service.ExecStart}
  EOF
  grep -q -- 'http://127.0.0.1:9119/' <<'EOF'
  ${service.ExecStartPost}
  EOF
  test '${service.ProtectSystem}' = 'strict'
  test '${if service.ProtectHome then "true" else "false"}' = 'false'
  grep -q -- '${hermesCfg.stateDir}' <<'EOF'
  ${builtins.concatStringsSep "\n" service.ReadWritePaths}
  EOF
  grep -q -- '${hermesCfg.workingDirectory}' <<'EOF'
  ${builtins.concatStringsSep "\n" service.ReadWritePaths}
  EOF
  touch $out
''
