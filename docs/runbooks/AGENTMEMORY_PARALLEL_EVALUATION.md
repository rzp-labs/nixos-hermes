# Agent Memory LLM runtime on nixos-hermes

Agent Memory is the active Hermes memory provider on `nixos-hermes`. The current target shape is not a shadow observer: the host runs Agent Memory as a NixOS-managed service, Hermes uses the `nix-managed-agentmemory-hermes-plugin` provider, and LLM-backed Agent Memory behavior is routed through the LAN CLIProxyAPI.

## Declarative service

The Den host graph imports `den/hosts/nixos-hermes/services/agentmemory.nix`, which defines and enables `services.agentmemory` by default for this host. Disable/rollback is one declarative change:

```nix
services.agentmemory.enable = false;
```

To keep the service running but remove LLM-backed behavior, use:

```nix
services.agentmemory.llm.enable = false;
```

The service runs as the `agentmemory` system user with persistent state under:

```text
/var/lib/agentmemory
```

Package pins:

- `@agentmemory/agentmemory`: `0.9.21`
- `iii-engine`: `0.11.2`

The Nix package uses the npm release tarball plus a fixed-output `node_modules` derivation. This intentionally avoids `npx -y`, global npm installs, or network-at-runtime package resolution in the systemd path.

## Listener contract

Expected local surfaces:

| Surface | Bind / URL |
| --- | --- |
| REST API | `http://127.0.0.1:3111/agentmemory/*` |
| Streams | `ws://127.0.0.1:3112` |
| Viewer | `http://127.0.0.1:3113` |
| iii bridge | `ws://127.0.0.1:49134` |

Upstream Agent Memory and the bundled `iii-config.yaml` bind REST/streams/viewer to loopback by default. The NixOS service also sets explicit loopback URLs and ports. Do not expose these listeners publicly.

## LLM provider contract

Agent Memory uses an OpenAI-compatible chat provider through CLIProxyAPI:

```env
OPENAI_BASE_URL=http://10.0.0.102:8317
OPENAI_MODEL=gpt-5.4-mini
AGENTMEMORY_LLM_TIMEOUT_MS=120000
OPENAI_TIMEOUT_MS=120000
EMBEDDING_PROVIDER=local
```

Important endpoint detail: Agent Memory `0.9.21` appends `/v1/chat/completions` internally, so `OPENAI_BASE_URL` must be the proxy root (`http://10.0.0.102:8317`), not `http://10.0.0.102:8317/v1`.

The CLIProxyAPI key is a raw SOPS secret readable only by the `agentmemory`
service user:

```nix
sops.secrets.cliproxyapi-key = {
  owner = "agentmemory";
  group = "agentmemory";
  mode = "0400";
};
```

The startup wrapper waits briefly for `/run/secrets/cliproxyapi-key`, reads it
inside the service process, and exports `OPENAI_API_KEY` there. Do not use
`LoadCredential` for this secret: during `nixos-rebuild test`/activation,
systemd can attempt to load credentials while sops-nix is rotating the
`/run/secrets` symlink, producing a transient `status=243/CREDENTIALS` start
failure that fails the rebuild even if auto-restart succeeds seconds later. The
key must not appear in Nix store-backed environment files or generated config.

## Runtime flags

Full Agent Memory runtime behavior is enabled, except the upstream Agent SDK fallback:

```env
AGENTMEMORY_ALLOW_AGENT_SDK=false
AGENTMEMORY_AUTO_COMPRESS=true
GRAPH_EXTRACTION_ENABLED=true
CONSOLIDATION_ENABLED=true
AGENTMEMORY_INJECT_CONTEXT=true
AGENTMEMORY_TOOLS=core
```

`AGENTMEMORY_ALLOW_AGENT_SDK=false` stays off because it is a separate fallback execution path and upstream warns it can spawn child-agent sessions that recurse through plugin hooks. The intended LLM path is CLIProxyAPI through `OPENAI_API_KEY`, not Agent SDK fallback.

`EMBEDDING_PROVIDER=local` is explicit so adding the OpenAI-compatible chat key does not silently move embedding traffic to the proxy. Change that only after CLIProxyAPI embedding support is separately proven and intentionally selected.

## Hermes integration

Hermes integration is declarative and split into two non-mutating paths:

- `den/hosts/nixos-hermes/services/hermes-agent/plugins.nix` pins the Agent Memory source commit matching npm `0.9.21` (`1838f4d74c3a0accdd3764e7a8ec155cc140b831`) and installs `integrations/hermes` through `services.hermes-agent.extraPlugins` with plugin name `agentmemory` enabled.
- `den/hosts/nixos-hermes/services/agentmemory.nix` configures `services.hermes-agent.mcpServers.agentmemory` to run the pinned local package directly:

  ```nix
  command = "${pkgs.agentmemory}/bin/agentmemory";
  args = [ "mcp" ];
  env.AGENTMEMORY_URL = "http://127.0.0.1:3111";
  ```

Do not replace this with upstream's `npx -y @agentmemory/mcp` examples. The Nix package already contains the canonical `agentmemory mcp` shim and keeps MCP package resolution pinned to the host closure.

Hermes' active memory provider is:

```nix
services.hermes-agent.settings.memory.provider = "nix-managed-agentmemory-hermes-plugin";
```

The plugin's internal name remains `agentmemory`, but the Hermes MemoryProvider loader selects user-installed providers by the symlink name under `$HERMES_HOME/plugins`.

## Mechanical validation

Run the config invariant check after edits:

```bash
nix build .#checks.x86_64-linux.agentmemory-service-config --no-link -L
```

For normal pre-PR validation:

```bash
tools/pre-pr-verify.sh
```

For changes that affect activation/deployment mechanics, use the heavier VM switch smoke from `AGENTS.md`.

## Runtime smoke

After an authorized host switch/restart, prove runtime separately from build proof:

```bash
systemctl show agentmemory.service -p ActiveState -p MainPID -p Environment --no-pager
systemctl status agentmemory.service --no-pager -l
journalctl -u agentmemory.service -n 160 --no-pager | grep -Ei 'llm|openai|noop|provider|consolid|graph|compress|inject|error|timeout'
curl -fsS http://127.0.0.1:3111/agentmemory/livez
curl -fsS http://127.0.0.1:3111/agentmemory/health | jq .
hermes mcp test agentmemory
hermes plugins list | grep -E 'agentmemory[[:space:]].*enabled'
hermes memory status | grep -E '^[[:space:]]*Provider:[[:space:]]+nix-managed-agentmemory-hermes-plugin\b'
```

Those commands prove service shape only. They are not enough to close LLM runtime work.

Run the behavior smoke:

```bash
tools/agentmemory-llm-smoke.sh --timeout 180
```

If the CLIProxyAPI process has a known systemd unit on the host, include it so the smoke reports whether proxy logs mention chat completions and the expected model:

```bash
tools/agentmemory-llm-smoke.sh --timeout 180 --cliproxy-unit <cliproxyapi-unit-name>
```

The smoke seeds a disposable marker, verifies Agent Memory records/searches it, exercises `/agentmemory/enrich` and the packaged pre-tool hook when available, runs graph extraction, and runs the consolidation pipeline. It closes its throwaway Agent Memory session with `/agentmemory/session/end` in a `finally` block and fails if that session is not `completed` with `endedAt`, so repeated smoke runs do not inflate the active-session inventory before Docker or source A/B diagnostics. It fails on disabled/skipped responses instead of treating flag presence as success.

For CLI lifecycle checks, use `hermes chat --continue -q ...` rather than the invalid global form `hermes --continue -q ...`. A 2026-05-22 ONE-100 probe resumed Hermes session `20260517_161811_05921c`, created/reused the matching Agent Memory session, and exited with Agent Memory status `completed` plus `endedAt`; active/unended session count stayed at 18 before and after. Treat this as evidence that the non-interactive CLI `--continue` happy path closes sessions on normal exit. It does not prove gateway soft-cache eviction or abrupt service termination closes sessions.

## Rollback

Fast runtime rollback:

```bash
sudo nixos-rebuild --rollback switch
```

Declarative follow-up rollback if only the LLM-backed path should be disabled:

```nix
services.agentmemory.llm.enable = false;
```

or flip individual flags in `den/hosts/nixos-hermes/services/agentmemory.nix` if a specific feature proves bad. Keep any runtime-only service restart as a smoke test, not the final fix.

## Ripcords

Rollback or disable the LLM-backed path if any of these occur:

- any Agent Memory listener binds publicly;
- the service uses runtime package installation;
- startup logs show no-op LLM provider warnings such as `No LLM provider key found`;
- repeated compression/consolidation/graph provider timeouts materially degrade Hermes usability;
- injected context is persistently misleading after correction;
- proxy traffic is unexpectedly high and not explained by live tool/session volume;
- Agent Memory blocks Hermes startup, gateway startup, or MCP discovery;
- rollback cannot be represented as declarative configuration.
