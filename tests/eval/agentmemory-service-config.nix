# tests/eval/agentmemory-service-config.nix
# Eval check: agentmemory systemd service + Hermes plugin wiring.
#
# Pure-evaluation assertion derivation extracted from flake.nix.
# Built via: nix build .#checks.x86_64-linux.agentmemory-service-config
{ pkgs, hostConfig, ... }:
let
  unit = hostConfig.systemd.services.agentmemory;
  env = unit.environment;
  service = unit.serviceConfig;
  stateDirectories = pkgs.lib.toList service.StateDirectory;
  cacheDirectories = pkgs.lib.toList service.CacheDirectory;
  hermesMcp = hostConfig.services.hermes-agent.mcpServers.agentmemory;
  hermesPluginNames = builtins.concatStringsSep "\n" (
    map toString hostConfig.services.hermes-agent.extraPlugins
  );
  hermesEnabledPlugins = builtins.concatStringsSep " " hostConfig.services.hermes-agent.settings.plugins.enabled;
in
pkgs.runCommand "agentmemory-service-config" { } ''
  set -eu
  test '${if hostConfig.services.agentmemory.enable then "true" else "false"}' = 'true'
  test '${if hostConfig.services.agentmemory.llm.enable then "true" else "false"}' = 'true'
  test '${hostConfig.services.agentmemory.llm.baseUrl}' = 'http://127.0.0.1:4000'
  test '${hostConfig.services.agentmemory.llm.model}' = 'gpt-5.4-mini'
  test '${toString hostConfig.services.agentmemory.llm.timeoutMs}' = '120000'
  test '${hostConfig.services.agentmemory.llm.embeddingProvider}' = 'local'
  test '${hostConfig.services.agentmemory.package.version}' = '0.9.21'
  test -d '${hostConfig.services.agentmemory.package}/lib/node_modules/@agentmemory/agentmemory/node_modules/@xenova/transformers'
  test -f '${hostConfig.services.agentmemory.package}/lib/node_modules/@agentmemory/agentmemory/node_modules/sharp/build/Release/sharp-linux-x64.node'
  (cd '${hostConfig.services.agentmemory.package}/lib/node_modules/@agentmemory/agentmemory' && ${pkgs.nodejs}/bin/node --input-type=module -e 'import("@xenova/transformers").then((m) => { if (typeof m.pipeline !== "function") process.exit(1); }).catch((err) => { console.error(err); process.exit(1); })')
  test '${hostConfig.services.agentmemory.package.passthru.iii-engine.version}' = '0.11.2'
  test '${env.HOME}' = '/var/lib/agentmemory'
  test '${env.AGENTMEMORY_URL}' = 'http://127.0.0.1:3111'
  test '${env.AGENTMEMORY_VIEWER_URL}' = 'http://127.0.0.1:3113'
  test '${env.AGENTMEMORY_ALLOW_AGENT_SDK}' = 'false'
  test '${env.AGENTMEMORY_AUTO_COMPRESS}' = 'true'
  test '${env.GRAPH_EXTRACTION_ENABLED}' = 'true'
  test '${env.CONSOLIDATION_ENABLED}' = 'true'
  test '${env.AGENTMEMORY_INJECT_CONTEXT}' = 'true'
  test '${env.AGENTMEMORY_TOOLS}' = 'core'
  test '${env.OPENAI_BASE_URL}' = 'http://127.0.0.1:4000'
  test '${env.OPENAI_MODEL}' = 'gpt-5.4-mini'
  test '${env.AGENTMEMORY_LLM_TIMEOUT_MS}' = '120000'
  test '${env.OPENAI_TIMEOUT_MS}' = '120000'
  test '${env.EMBEDDING_PROVIDER}' = 'local'
  test '${env.TRANSFORMERS_CACHE}' = '/var/cache/agentmemory/transformers'
  test '${env.XDG_CACHE_HOME}' = '/var/cache/agentmemory'
  grep -q -- 'agentmemory-transformers-runtime.mjs' <<'EOF'
  ${env.NODE_OPTIONS}
  EOF
  test '${if builtins.hasAttr "OPENAI_API_KEY" env then "true" else "false"}' = 'false'
  test '${env.III_REST_PORT}' = '3111'
  test '${env.III_STREAMS_PORT}' = '3112'
  test '${env.III_STREAM_PORT}' = '3112'
  test '${env.III_VIEWER_PORT}' = '3113'
  test '${env.III_ENGINE_URL}' = 'ws://127.0.0.1:49134'
  test '${service.User}' = 'agentmemory'
  test '${service.Group}' = 'agentmemory'

  test '${builtins.concatStringsSep " " stateDirectories}' = 'agentmemory agentmemory/data'
  test '${builtins.concatStringsSep " " cacheDirectories}' = 'agentmemory agentmemory/transformers'
  test '${service.WorkingDirectory}' = '/var/lib/agentmemory'
  test '${service.TimeoutStopSec}' = '10s'
  test '${hermesMcp.command}' = '${hostConfig.services.agentmemory.package}/bin/agentmemory'
  test '${builtins.concatStringsSep " " hermesMcp.args}' = 'mcp'
  test '${hermesMcp.env.AGENTMEMORY_URL}' = 'http://127.0.0.1:3111'
  agentmemory_plugin_path=$(grep -- 'agentmemory-hermes-plugin-0.9.21' <<'EOF' | head -n 1
  ${hermesPluginNames}
  EOF
  )
  test -n "$agentmemory_plugin_path"
  for hook in prefetch sync_turn on_session_end on_pre_compress on_memory_write system_prompt_block; do
    grep -q -- "- $hook" "$agentmemory_plugin_path/plugin.yaml"
  done
  grep -qw -- 'agentmemory' <<'EOF'
  ${hermesEnabledPlugins}
  EOF
  test '${hostConfig.services.hermes-agent.settings.memory.provider}' = 'nix-managed-agentmemory-hermes-plugin'
  test '${service.ProtectSystem}' = 'strict'
  test '${if service.ProtectHome then "true" else "false"}' = 'true'
  grep -q -- '/bin/iii --config ' '${service.ExecStart}'
  grep -q -- 'export OPENAI_API_KEY=' '${service.ExecStart}'
  grep -q -- 'export OPENAI_API_KEY=local-auth-gateway' '${service.ExecStart}'
  test '${if builtins.hasAttr "ExecStartPre" service then "true" else "false"}' = 'false'
  grep -q -- '${pkgs.bash}/bin' <<'EOF'
  ${env.PATH}
  EOF
  grep -q -- '${hostConfig.services.agentmemory.package.passthru.iii-engine}/bin' <<'EOF'
  ${env.PATH}
  EOF
  grep -q -- 'agentmemory-iii-config.yaml' <<'EOF'
  ${builtins.readFile service.ExecStart}
  EOF
  grep -q -- 'cron_store.db' '${builtins.head unit.restartTriggers}'
  grep -q -- 'state_store.db' '${builtins.head unit.restartTriggers}'
  grep -q -- 'stream_store' '${builtins.head unit.restartTriggers}'
  if grep -qi -- 'in_memory' '${builtins.head unit.restartTriggers}'; then
    echo 'agentmemory iii config must not use in_memory stores' >&2
    exit 1
  fi
  grep -q -- 'agentmemory-ready-check' <<'EOF'
  ${toString service.ExecStartPost}
  EOF
  grep -q -- '${pkgs.curl}/bin' <<'EOF'
  ${env.PATH}
  EOF
  case '${service.ExecStart}' in
    *'/bin/agentmemory --tools core'*)
      echo 'agentmemory.service must supervise iii-engine directly, not the daemonizing CLI wrapper' >&2
      exit 1
      ;;
  esac
  touch $out
''
