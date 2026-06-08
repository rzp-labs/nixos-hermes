# AGENTS.md — Working Context for AI Agents

This file is the authoritative guide for AI agents (Claude, Codex, etc.) working on this repository. Read it before touching any file.

## Project in One Sentence

A fully declarative NixOS flake configuration for a bare-metal AI agent host running `hermes-agent` (NousResearch) as a systemd service, delivering a personal, always-on assistant.

## Repository Layout

```text
nixos-hermes/
├── tests/
│   ├── assets/
│   │   ├── age-test-key.txt             # throwaway age key (committed — encrypts only dummy test data)
│   │   └── test-secrets.yaml            # sops-encrypted dummy secrets for VM tests
│   ├── eval/                            # pure-eval assertion checks (one file per check)
│   │   ├── default.nix                  # aggregator: feeds host config/pkgs into each check
│   │   ├── hermes-runtime-packaging.nix # hermes venv imports + opus shim
│   │   ├── repowise-nix-tooling.nix     # Repowise / vite-plus / cli-proxy-api wiring
│   │   ├── agentmemory-service-config.nix # agentmemory unit + Hermes plugin wiring
│   │   ├── netdata-service-config.nix   # Netdata config + observe wrapper + MCP wiring
│   │   └── hindsight-service-config.nix # asserts Hindsight memory stays disabled
│   └── default.nix                      # nixosTest VM test suite
├── checks/
│   └── pre-commit.nix                   # git-hooks.nix hook config (dev shell + pre-commit-check)
├── apps/
│   └── default.nix                      # flake apps: nixos-anywhere, disko, *-smoke wrappers
├── flake.nix                            # thin manifest: inputs/outputs, host definition, wiring
├── .github/workflows/flakehub-publish-rolling.yml # CI: publish to FlakeHub on push to main
├── .sops.yaml                           # sops encryption policy (age)
├── .agents/                             # committed local agent skills (GitButler workflow)
├── .secrets/                            # GITIGNORED — plaintext secrets, local only
│   └── hermes-secrets.yaml              # never commit; encrypt before use
├── hosts/
│   └── hermes/
│       ├── default.nix                  # host entry: identity constants + imports
│       ├── disk-config.nix              # disko layout (imported; generates fileSystems.*)
│       ├── hardware.nix                 # boot, initrd, kernel, GPU, ZFS services (filesystems via disko)
│       ├── provision.nix                # host-specific activation scripts (one-shot provisioning + recurring refresh)
│       ├── sops.nix                     # sops-nix secret bindings (host-specific)
│       ├── virtualisation.nix           # Docker/libvirt host substrate and host-specific group memberships
│       └── secrets/                     # committed SOPS-encrypted files
├── modules/
│   ├── system.nix                       # locale, tz, networking, packages, sudo
│   ├── home-manager.nix                 # Home Manager wiring for admin/operator user environment
│   ├── hermes-agent.nix                 # hermes service declaration
│   ├── hermes-dashboard.nix             # native Hermes dashboard service module
│   ├── hermes-plugins.nix               # declarative Hermes plugin packages/enables
│   ├── packages.nix                     # nixpkgs overlays (llm-agents.nix + local workarounds, Repowise)
│   └── users.nix                        # immutable user + SSH key declarations
```

---

## Technology Stack

| Layer | Tool |
|-------|------|
| OS | NixOS (nixpkgs unstable via FlakeHub `NixOS/nixpkgs/0`) |
| Nix runtime | Determinate Nix (via `determinate` flake input) |
| Secret management | sops-nix + age |
| Storage | ZFS (`rpool`, mirror) |
| Boot | systemd-boot, dual ESP |
| Agent service | `hermes-agent.nixosModules.default` |
| CI | GitHub Actions + DeterminateSystems stack |

---

## Coding Conventions

### Nix Style

- Module function heads use named args: `{ config, pkgs, lib, ... }:`
- One logical concern per file; do not conflate hardware and service config.
- Comments explain *why*, not *what* the code already says.
- Prefer `lib.mkDefault` only at genuine override boundaries; omit where the value is unconditional.

### Secrets

- **Never commit plaintext secrets.** `.secrets/` is `.gitignore`d; it exists only for local templating.
- The committed encrypted secrets live under `hosts/hermes/secrets/`.
- The `sops age` key is `/etc/secrets/age.key` on the host. The corresponding public key is registered in `.sops.yaml`. Do not change the public key in `.sops.yaml` without re-encrypting every secret file.
- `.secrets/hermes-secrets.yaml` is the plaintext template (`gitignored`). Workflow: edit locally → `sops --encrypt .secrets/hermes-secrets.yaml > hosts/hermes/secrets/hermes-secrets.yaml` → commit the encrypted file → never commit the plaintext.
- When adding a new secret key: add it to `.secrets/hermes-secrets.yaml`, add the `sops.secrets.<name>` binding in `hosts/hermes/sops.nix`, then re-encrypt.

### Users

- `users.mutableUsers = false` — the NixOS activation will reject any user state not described in `users.nix`. Do not add users imperatively on the host.
- Authentication is via SSH key only. Do not add password hashes unless explicitly requested.
  requested.
- `admin` has `wheel` and should have `security.sudo.wheelNeedsPassword = false` set (or equivalent) since there is no password configured.

### Git Hygiene

> **Push is not the approval gate; PR creation is.** Push focused, non-PR feature branches for remote visibility unless explicitly told not to. Do not open PRs, request reviews, merge, or push churn onto existing PR branches without explicit intent.

- The repo is **public**. Never commit SSH private keys, age private keys, plaintext secrets, IP-to-identity mappings, or personal information.
- The public SSH authorized keys already in the repo are acceptable (by design).
- Commit messages: imperative mood, present tense, ≤72 chars subject line.
- Before opening a PR, curate the GitButler stack into atomic, pickable commits. Once a PR exists, batch follow-up fixes because each push may trigger CI/review automation.

### Linear Agent Workflow

Linear is the durable coordination layer for agent work. Work should start from a scoped Linear issue, use compact branch names like `yui/ONE-29`, and end with an evidence comment containing branch, commit, changed files, validation, and any runtime follow-up.

Use the packaged `linear` CLI for routine agent interactions where possible. It authenticates non-interactively through `LINEAR_API_KEY` from the Hermes secret environment and avoids the headless OAuth problem in Linear's hosted MCP path. Prefer stable JSON output for scripts/reports:

```bash
linear issues get ONE-29 --output json
linear issues list --team ONE --output json
linear issues comment ONE-29 --body "Validation passed: ..."
linear issues update ONE-29 --state Review
```

Do not use opaque local Python scripts for normal Linear issue operations; if the CLI lacks coverage, use transparent GraphQL/curl commands and document the gap. Do not enable hosted Linear MCP in the default Hermes startup path until service-user OAuth bootstrap is proven.

### GitButler Workflow

This workspace is configured for GitButler. The local agent skill lives at
`.agents/skills/gitbutler/`; read `.agents/skills/gitbutler/SKILL.md` before
any version-control write operation.

- Use `but` for version-control mutations (`but status -fv`, `but commit`,
  `but branch new`, `but amend`, `but absorb`, `but push`, `but pr new`).
- Read-only `git` inspection is still fine. Do not use `git add`, `git commit`,
  `git checkout`, `git merge`, `git rebase`, `git stash`, or `git push` here.
- Push non-PR GitButler branches with `but push` for remote visibility unless
  explicitly told not to. PR creation (`but pr new`), review requests, merge,
  and push churn on already-open PR branches remain explicit approval boundaries.
- GitButler wraps the pre-commit hook and preserves the original hook as
  `.git/hooks/pre-commit-user`, so normal Nix/gitleaks/formatting hooks still
  run while direct commits to `gitbutler/workspace` are blocked.

See `docs/guides/GITBUTLER_WORKFLOW.md` for the full workflow and hook notes.

### Testing Ladder

Right tool, right job. Pick the lightest tool that covers the change.

| Change type | Tool | Root? |
|---|---|---|
| Nix eval / syntax | `nix flake check --no-build` | No |
| Package add / module option | `nixos-rebuild dry-build --flake .#nixos-hermes` | No |
| systemd unit change | `nixos-rebuild dry-activate` | Yes |
| Release-line / channel bump | eval + dry-build + `dry-activate` + critical option/unit diff + ZFS snapshot + `nixos-rebuild test` | Mixed |
| Activation script change | `nix build .#checks.x86_64-linux.<test>` (VM) | No |
| Real secrets / hardware / network | `nixos-rebuild test` | Yes |

For local flake `nixos-rebuild test` validation, use a clean repo copy at `/home/admin/workspace/nixos-hermes` with all unrelated GitButler branches unapplied and only the target branch under test applied. This proves the local flake without contamination from the agent workspace's other applied stacks. Always run `sudo nixos-rebuild test --flake .#nixos-hermes -L` before any persistent switch so reboot rollback remains available if the tested generation misbehaves. Before live-host mutation, take a ZFS recovery snapshot such as `sudo zfs snapshot -r rpool@pre-<change>-$(date -u +%Y%m%dT%H%M%SZ)` so filesystem/runtime state has a known-good restore point, not just Nix generation rollback. If a failed `test` leaves `/run/current-system` on a temporary generation while `/nix/var/nix/profiles/system` still points at the old boot-default generation, reboot back to boot-default before snapshotting and continuing. Live `nixos-rebuild switch` remains FlakeHub-based, not local-workspace based, unless explicitly authorized otherwise: after local host validation passes, open/review/merge the PR, wait for CI and FlakeHub publication, then switch from the remote published flake.

The VM tests live under `tests/` and run via QEMU — no root needed.
Pure-evaluation assertion checks (no guest boot) live under `tests/eval/`;
both surface through the flake `checks.x86_64-linux.*` output.
`checks.x86_64-linux.vm-switch-smoke` is the heaviest repo-owned smoke:
it boots a VM, switches to a prebuilt target system inside the guest with
`switch-to-configuration switch`, and verifies `/etc` plus
`/run/current-system` moved. Use it when build/dry-activate proof is not
enough for activation or switch-time behavior. It intentionally does not
exercise guest-side `nixos-rebuild` flake evaluation or network/cache access.
VM tests are the right tool when activation scripts change, but may also
be valuable for other changes where the build alone is insufficient.
Use judgment — the table above is guidance, not a hard constraint.
`dry-activate` runs `switch-to-configuration dry-activate` to diff
systemd units without applying changes — needs root but does not
mutate the running system. Treat it as risk discovery, not proof: it shows
which reloads/restarts would be attempted, but cannot prove the live daemon will
complete them. For release-line/channel bumps, also diff critical options and
units against the boot-default generation before the first live `test`; defaults
can change core services even when the handwritten config diff is small. In
particular, keep broad channel bumps from silently migrating D-Bus
implementation (`dbus-daemon` -> `dbus-broker`) unless that migration is the
explicit goal and has reboot/restart-shaped validation.

**Exception to the age private key rule:** `tests/assets/age-test-key.txt`
is a throwaway key committed intentionally — it encrypts only dummy test
values and has no real-world value. It is allowlisted in `.gitleaks.toml`.

---

## What Each Nix File Owns

### `flake.nix`

*Thin manifest: input pins + output wiring. Single host output: `nixosConfigurations.nixos-hermes`.*

- Manages input pins.
- Do not add multiple hosts without a corresponding refactor of the module tree.
- Keep it thin. Output *logic* (test bodies, hook config, app wrappers) lives in
  dedicated files that `flake.nix` imports — see `tests/eval/`, `checks/`, and
  `apps/` below. When adding an output, add a file and wire it here; do not inline
  large attrsets back into `flake.nix`.
- Make platform boundaries explicit at the import/derivation-definition site, not
  only at the final attribute merge. If an output is Linux-only, put its
  `callPackage`, `import`, or `writeShellApplication` binding inside the
  `system == "x86_64-linux"` guard even when Nix laziness would avoid forcing it
  on Darwin. This is readability policy: reviewers should see unsupported systems
  are never asked to construct Linux-only values.

*`nixosModules.default` convention*

- In flake outputs, `.default` is the canonical name for a flake's primary export of a given type — analogous to `packages.default`.
- `Determinate.nixosModules.default` and `hermes-agent.nixosModules.default` are values from two entirely separate flakes; naming collision is impossible.
- The NixOS module system merges all entries in the `modules` list regardless of where they came from.

*`Determinate.nixosModules.default` owns `nix.package`.*

- Do not set `nix.package` elsewhere in the module tree — the `Determinate` module manages `nix.package`.
- Duplicate declarations will cause an evaluation error.

*Flake inputs use FlakeHub URLs where possible, with fallback to GitHub.*

- `NixOS/nixpkgs/0` is FlakeHub's semver alias for nixpkgs unstable (`0` = pre-1.0 channel).
- FlakeHub Cache works best when inputs are FlakeHub-sourced.

> Do not switch a FlakeHub-published input back to a raw GitHub URL.

- Exceptions must be documented and currently include:
  - `NixOS/nixpkgs` as `nixpkgs-llama`
    - Temporarily pinned to a raw GitHub commit because the primary FlakeHub
      `NixOS/nixpkgs/0` input lagged package versions needed by this host.
    - Currently supplies `bun` and `llama-cpp` with Gemma 4 support until
      FlakeHub `NixOS/nixpkgs/0` catches up.
    - Netdata currently uses this package set as a base plus a scoped package
      override in `hosts/hermes/netdata.nix` because both pinned nixpkgs inputs
      lag Netdata Cloud's required stable agent release.
  - `nousresearch/hermes-agent`
    - Not published to FlakeHub at this time.
  - `nix-community/nixos-anywhere`
    - No release consumable as a flake input (`https://flakehub.com/f/nix-community/nixos-anywhere/*` returns 404 on archive fetch).
    - Pinned via `flake.lock` so bootstrap runs are reproducible; revisit when upstream publishes a version.
  - `numtide/llm-agents.nix`
    - Not published to FlakeHub at this time.

### `tests/eval/`

*Pure-evaluation assertion checks, one file per check.*

- Each `tests/eval/<name>.nix` is a function `{ pkgs, hostConfig, hostPkgs, ... }:`
  returning a `runCommand` derivation that asserts on the *built* host config
  (unit env, package versions, wrapper script contents, plugin wiring, …).
- `tests/eval/default.nix` is the aggregator: it takes the evaluated
  `hostSystem` once and feeds `config`/`pkgs` into each check, then surfaces them
  through `flake.nix`'s `checks.x86_64-linux.*` output.
- These are evaluation/build checks, **not** VM tests — they sit alongside the VM
  suite in `tests/` but never boot a guest. Run one with
  `nix build .#checks.x86_64-linux.<name>`.
- Path literals inside a check resolve relative to the file, so reference repo
  paths as `../../packages/...`, `../../hosts/...`, etc. — not `./...`.

### `checks/pre-commit.nix`

*git-hooks.nix hook configuration.*

- Returns the `git-hooks.lib.<system>.run` result. Consumed twice: the dev shell
  reads `.enabledPackages`/`.shellHook`, and `flake.nix` exposes the whole
  derivation as `checks.<system>.pre-commit-check`.
- `src = ../.` is the repo root (the file lives one level down in `checks/`).

### `apps/default.nix`

*Flake apps for a single dev system.*

- Install-time CLIs (`nixos-anywhere`, `disko`) plus Linux-only operational
  smokes that wrap scripts under `../tools`. Invoked as `nix run .#<app>`.
- Receives `{ pkgs, lib, system, nixos-anywhere, disko }` from `flake.nix`; the
  `x86_64-linux`-only apps are added via `lib.optionalAttrs`.
- Keep Linux-only wrapper derivations inside the `x86_64-linux` attrset's local
  `let`. Do not define them in the file-level `let` and rely on Nix laziness to
  avoid Darwin evaluation.

### `hosts/hermes/default.nix`

*Host entry point.*

- Contains machine-specific identity constants (`hostName`, `hostId`, `stateVersion`, `hostPlatform`) and the import list. Nothing else.
- These constants must never be extracted into shared modules.

### `hosts/hermes/hardware.nix`

*Everything tied to physical hardware.*

- Includes: boot, initrd, kernel, GPU, and bootloader configuration.
- Host-specific storage service options (e.g. `services.zfs.autoScrub`, `services.zfs.trim`) also live here because they only apply to this host's ZFS configuration and must not leak into the portable `modules/system.nix`.
- Filesystem mounts themselves are generated by `disko` from `disk-config.nix`, not declared here.

### `hosts/hermes/disk-config.nix`

*Declarative disk layout consumed by `disko`.*

- Describes GPT partitions and the ZFS pool/dataset structure.
- Imported as a NixOS module via `disko.nixosModules.default`, so `disko` generates `fileSystems.*` entries at evaluation time from the `mountpoint = "..."` attributes on each partition and dataset.

> Do not declare `fileSystems.*` manually in `hardware.nix` — that would duplicate what `disko` produces.

At install time:
  - The same file is also consumed by `nix run .#disko -- --mode disko hosts/hermes/disk-config.nix`.
  - Exposed as a flake app so the CLI uses the same `flake.lock` pin as the NixOS module, eliminating module/CLI version skew.

After first install:
  - The partition/pool sections are effectively reference documentation.
  - Changing them does not reformat disks, but the `mountpoint` attributes remain live: they control mounting on every rebuild.

### `hosts/hermes/sops.nix`

*Maps SOPS-encrypted files to runtime paths.*

- Lives alongside `secrets/` so that `./secrets/...` paths resolve correctly.
- The `sops age` key path (`/etc/secrets/age.key`) must not change without updating this file.

### `hosts/hermes/virtualisation.nix`

*Host-local Docker/libvirt substrate.*

- Owns Docker, libvirt/QEMU, virtiofsd registration, and host-specific operator group memberships needed to use those services.
- Keep Docker/libvirt group memberships here, not in `modules/users.nix`, because those groups only exist on hosts that enable the corresponding services.
- Docker group access is root-equivalent on this host. Adding `hermes` to `docker` is a deliberate operational trust decision for container-first workload proving, not a sandbox boundary.
- The Docker ZFS storage driver is for the bare-metal ZFS host only. Guest Docker inside VMs/microVMs should use overlay2 on ext4/xfs to avoid stacked CoW over host ZFS.

### `hosts/hermes/provision.nix`

*Host-specific activation scripts. Two categories:*

- **One-shot provisioning:** activation scripts with a file-existence guard that run once on first boot to seed runtime state. Rebuilds do not clobber runtime-evolved state. To re-provision: delete the target file on the host, then rebuild.
- **Recurring refresh:** activation scripts with no guard that run on every activation. Used for credentials and other state that must stay in sync with sops secrets.
- Lives in `hosts/hermes/` (not `modules/`) because provisioning is host-specific,
  not portable across hosts.
- To re-provision a file: delete it on the host, then rebuild.

### `modules/packages.nix`

*nixpkgs overlays and NixOS packaging workarounds.*

- Owns the nixpkgs overlay that injects packages not yet in the pinned channel.
  Community overlays (e.g. `llm-agents`) are added here until they land upstream.
- Also owns workarounds for NixOS packaging behaviour that affect services on this
  host (e.g. the `opusCtypesShim` for CPython's patched `ctypes.util.find_library`).
  Keep that shim scoped to Opus discovery; Hindsight's agent-facing Python client
  belongs in `services.hermes-agent.extraPythonPackages`, not in this `sitecustomize.py`.
- Exposes shims via the overlay (e.g. `pkgs.opusCtypesShim`) so service modules
  can consume them without coupling to this file directly.
- Owns the standalone Repowise Nix flake (`packages/repowise-nix`) and `repowise-nix` wrapper. See
  `docs/guides/REPOWISE.md` for runtime usage and credential boundaries.

### `modules/system.nix`

*Base system settings.*

- Includes: locale, timezone, networking, openssh, sudo, packages, and session variables.
- No host-specific values.

### `modules/home-manager.nix`

*User-scoped interactive/operator environment.*

- Owns Home Manager module configuration for user environments managed on this host.
- Keep human/operator shell UX and per-user toolchains here rather than in host-wide shell init.
- Shared user-facing toolchains used by both the operator and the Hermes service persona belong here for each intended home, not in `environment.systemPackages` by accident.
- Add other service accounts deliberately; review their runtime state boundary before Home Manager owns additional home files.

### `modules/hermes-agent.nix`

*The `hermes-agent` service declaration.*

- All core `services.hermes-agent.*` options belong here.
- Secrets are referenced by name from the `sops` bindings.

### `modules/hermes-dashboard.nix`

*Native Hermes dashboard/admin backend service module.*

- Owns `services.hermes-dashboard.*` options and the `hermes-dashboard.service` systemd unit.
- Keep the reusable service shape here; host files should only enable it and set host-specific option values.
- The dashboard consumes the configured Hermes package/runtime state but runs as a separate foreground process and listener.

### `modules/hermes-plugins.nix`

*Declarative Hermes plugin installation and enablement.*

- Entry-point Python plugins belong in `services.hermes-agent.extraPythonPackages`.
- Directory plugins belong in `services.hermes-agent.extraPlugins`.
- Plugin runtime binaries belong in `services.hermes-agent.extraPackages`.
- Plugin names must also be enabled in `services.hermes-agent.settings.plugins.enabled`.
- See `docs/guides/HERMES_PLUGINS_NIX.md` before adding or updating plugins.

### `modules/users.nix`

*Immutable user definitions.*

- The only place user accounts and authorized SSH keys should appear.
- Lives in `modules/` because it is portable across hosts.

---

## Testing and Validation

For Hindsight/memory-provider wiring changes, `nix flake check` and service health are not enough. Run the observable continuity smoke too:

```bash
tools/pre-pr-verify.sh --hindsight-live
# or directly:
tools/hindsight-continuity-smoke.sh --timeout 180
```

That smoke must prove the Hermes runtime can import `hindsight_client`, direct retain extracts a fact, bank stats are visible, and direct recall returns the retained marker. After context compaction or continuity failures, give at most one concise accountability note, then move to evidence, diagnosis, and durable fixes; repeated apology/explanation loops are the bug, not the remedy.

### Local Check (No Host Needed)

```bash
nix flake check
```

### Dry-Run Build (Evaluates but Does Not Activate)

```bash
nixos-rebuild dry-build --flake .#nixos-hermes
```

## First Install

A dedicated runbook is available in `docs/runbooks/FIRST_INSTALL.md`.

---

## Hermes Agent Configuration

See `docs/guides/HERMES_AGENT_CONFIGURATION.md` for details.

---

## Deployment Topology

```text
GitHub (rzp-labs/nixos-hermes)
    │
    ├─ push to main → CI: publish flake to FlakeHub
    │
    └─ manual: nixos-rebuild switch → nixos-hermes
                                           │
                                    ZFS mirror rpool
```

The host IP is static and enforced at the gateway. If it changes, update your SSH config; the NixOS configuration itself uses hostnames, not IPs.
