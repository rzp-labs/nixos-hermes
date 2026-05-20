# Agent Memory parallel evaluation

Agent Memory is installed on `nixos-hermes` as a parallel observer beside Hindsight. The first milestone is infrastructure only: Agent Memory may observe and answer explicit probes, but it must not inject context into routine Hermes turns until the evaluation gates say it is safe.

## Declarative service

The host imports `hosts/hermes/agentmemory.nix`, which defines and enables `services.agentmemory` by default for this host. Disable/rollback is one declarative change:

```nix
services.agentmemory.enable = false;
```

or remove the host import if the evaluation is fully abandoned.

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

Upstream Agent Memory and the bundled `iii-config.yaml` bind REST/streams/viewer to loopback by default. The NixOS service also sets explicit loopback URLs and ports. Do not expose these listeners publicly during the shadow evaluation.

## Conservative flags

The service starts with influence-changing and expensive features off:

```env
AGENTMEMORY_ALLOW_AGENT_SDK=false
AGENTMEMORY_AUTO_COMPRESS=false
GRAPH_EXTRACTION_ENABLED=false
CONSOLIDATION_ENABLED=false
AGENTMEMORY_INJECT_CONTEXT=false
AGENTMEMORY_TOOLS=core
```

Hindsight remains the Hermes memory provider during this milestone.

## Hermes integration

Hermes integration is declarative and split into two non-mutating paths:

- `modules/hermes-plugins.nix` pins the Agent Memory source commit matching npm `0.9.21` (`1838f4d74c3a0accdd3764e7a8ec155cc140b831`) and installs `integrations/hermes` through `services.hermes-agent.extraPlugins` with plugin name `agentmemory` enabled.
- `hosts/hermes/agentmemory.nix` configures `services.hermes-agent.mcpServers.agentmemory` to run the pinned local package directly:

  ```nix
  command = "${pkgs.agentmemory}/bin/agentmemory";
  args = [ "mcp" ];
  env.AGENTMEMORY_URL = "http://127.0.0.1:3111";
  ```

Do not replace this with upstream's `npx -y @agentmemory/mcp` examples. The Nix package already contains the canonical `agentmemory mcp` shim and keeps MCP package resolution pinned to the host closure.

`memory.provider` remains `hindsight` during the shadow evaluation. The Agent Memory provider plugin is installed and discoverable, but switching the active Hermes provider to `agentmemory` is an influence change and belongs behind the later evaluation gates.

## Evaluation gates

Promotion is gated by evidence, not by the service merely staying up:

| Gate | Criteria | Flags that may change after pass |
| --- | --- | --- |
| M1: declarative observer | Build/dry-build pass, unit invariants prove loopback-only/pinned foreground service shape, systemd reports the service active, journald has no startup error, Hermes MCP/plugin discovery works, and Hindsight remains the active provider. | None; keep observer-only mode. |
| M2: automatic capture proof | A fixed session set produces Agent Memory records without manual API calls, captured content is redacted enough for this host by source/static inspection plus one representative observation if needed, and capture does not alter Hermes prompts/tool routing. | Consider `AGENTMEMORY_ALLOW_AGENT_SDK=true` only if the SDK path is required for capture and remains non-influential. |
| M3: quality/noise bake-off | The comparison query set shows useful recall with acceptable false positives/duplicates versus Hindsight, including explicit misses and bad recalls. | Consider `GRAPH_EXTRACTION_ENABLED=true` or `CONSOLIDATION_ENABLED=true` one at a time for a measured retest. |
| M4: controlled influence trial | Human-approved narrow profile/session, fixed rollback point, prompt diff captured, no private/irrelevant memory injection, and Hindsight remains available as fallback. | Only then consider `AGENTMEMORY_INJECT_CONTEXT=true` for that controlled scope. |

Fail any ripcord below and stop promotion; do not relax another flag to compensate for a failed gate.

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

After an authorized host switch/restart, prove runtime separately from build proof with native system interfaces rather than a checked-in wrapper:

```bash
systemctl status agentmemory.service --no-pager -l
journalctl -u agentmemory.service -n 80 --no-pager
curl -fsS http://127.0.0.1:3111/agentmemory/livez
hermes mcp test agentmemory
hermes plugins list | grep -E 'agentmemory[[:space:]].*enabled'
hermes memory status | grep -E '^[[:space:]]*Provider:[[:space:]]+hindsight\b'
```

Those commands prove the M1 runtime boundary: the supervised service is up, failures are visible in journald, the REST listener answers locally, Hermes can discover Agent Memory tools, the plugin is enabled, and Agent Memory has not replaced Hindsight as the active memory provider.

Do not turn this into a bespoke safety CLI. Redaction belongs in M2 automatic-capture evaluation: verify the upstream/source redaction path and use one representative observation only if the source inspection leaves an actual question. Manual REST remember/search probes are not evidence of automatic capture and should not be used to promote beyond M1.

## Ripcords

Disable Agent Memory and stop promotion if any of these occur:

- any listener binds publicly;
- the service uses runtime package installation;
- unredacted real secrets/private infrastructure are captured during automatic-capture evaluation;
- Agent Memory blocks Hermes startup, gateway startup, or MCP discovery;
- rollback cannot be represented as declarative configuration.
