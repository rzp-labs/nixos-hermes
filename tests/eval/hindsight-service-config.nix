# tests/eval/hindsight-service-config.nix
# Eval check: Hindsight memory is fully disabled in favor of agentmemory.
#
# Pure-evaluation assertion derivation extracted from flake.nix.
# Built via: nix build .#checks.x86_64-linux.hindsight-service-config
{ pkgs, hostConfig, ... }:
let
  serviceNames = builtins.attrNames hostConfig.systemd.services;
  hermesMemory = hostConfig.services.hermes-agent.settings.memory;
  hermesEnvNames = builtins.attrNames hostConfig.services.hermes-agent.environment;
  hermesAfter = hostConfig.systemd.services.hermes-agent.after;
  hermesWants = hostConfig.systemd.services.hermes-agent.wants;
in
pkgs.runCommand "hindsight-service-config" { } ''
  set -eu
  test '${if hostConfig.services.hindsightMemory.enable then "true" else "false"}' = 'false'
  test '${hermesMemory.provider}' = 'nix-managed-agentmemory-hermes-plugin'
  test '${if builtins.elem "hindsight-embed" serviceNames then "true" else "false"}' = 'false'
  test '${if builtins.elem "hindsight-postgres-init" serviceNames then "true" else "false"}' = 'false'
  test '${if builtins.elem "llama-server" serviceNames then "true" else "false"}' = 'false'
  test '${if builtins.elem "hindsight-embed.service" hermesAfter then "true" else "false"}' = 'false'
  test '${if builtins.elem "hindsight-embed.service" hermesWants then "true" else "false"}' = 'false'
  test '${if builtins.elem "HINDSIGHT_MODE" hermesEnvNames then "true" else "false"}' = 'false'
  test '${if builtins.elem "HINDSIGHT_API_URL" hermesEnvNames then "true" else "false"}' = 'false'
  test '${if builtins.elem "HINDSIGHT_BANK_ID" hermesEnvNames then "true" else "false"}' = 'false'
  touch $out
''
