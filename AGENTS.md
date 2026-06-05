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
├── den/                                 # Den model + rendered host/user/HM/system baseline
│   ├── default.nix                      # Den model module entrypoint
│   ├── schema.nix                       # repo-local host/user schema facts
│   ├── entities.nix                     # inventory facts + migrated Den render aspects
│   └── lab.nix                          # local lab namespace/category skeleton
├── checks/
│   └── pre-commit.nix                   # git-hooks.nix hook config (dev shell + pre-commit-check)
├── apps/
│   └── default.nix                      # flake apps: nixos-anywhere, disko, *-smoke wrappers
├── flake.nix                            # thin manifest: inputs/outputs; host modules selected from Den
├── .github/workflows/flakehub-publish-rolling.yml # CI: publish to FlakeHub on push to main
├── .sops.yaml                           # sops encryption policy (age)
├── .agents/                             # committed local agent skills (GitButler workflow)
├── .secrets/                            # GITIGNORED — plaintext secrets, local only
│   └── hermes-secrets.yaml              # never commit; encrypt before use
└── den/hosts/nixos-hermes/              # Den-owned host modules and encrypted payloads
    ├── storage/disk-config.nix          # disko layout (imported; generates fileSystems.*)
    ├── secrets/payload/                 # committed SOPS-encrypted files
    ├── platform/                        # host platform leaves still awaiting Den rendering
    ├── services/                        # host runtime services
    └── shared/                          # host-selected shared NixOS modules
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
- Keep substantial shell/Python out of inline Nix strings. If runtime glue is more than a tiny command, put it in a dedicated package/script file so it can be formatted, linted, typechecked, reviewed, and tracked independently.
- Do not bundle independent services into one module just because they are adjacent in the migration path; each service gets its own `.nix` owner unless there is a real shared abstraction.
- Comments explain *why*, not *what* the code already says.
- Prefer `lib.mkDefault` only at genuine override boundaries; omit where the value is unconditional.

### Secrets

- **Never commit plaintext secrets.** `.secrets/` is `.gitignore`d; it exists only for local templating.
- The committed encrypted secrets live under `den/hosts/nixos-hermes/secrets/payload/`.
- The `sops age` key is `/etc/secrets/age.key` on the host. The corresponding public key is registered in `.sops.yaml`. Do not change the public key in `.sops.yaml` without re-encrypting every secret file.
- `.secrets/hermes-secrets.yaml` is the plaintext template (`gitignored`). Workflow: edit locally → `sops --encrypt .secrets/hermes-secrets.yaml > den/hosts/nixos-hermes/secrets/payload/hermes-secrets.yaml` → commit the encrypted file → never commit the plaintext.
- When adding a new secret key: add it to `.secrets/hermes-secrets.yaml`, add the binding metadata under `den.hosts.x86_64-linux.nixos-hermes.secrets.bindings` in `den/entities.nix`, then re-encrypt.

### Users

- `users.mutableUsers = false` — the NixOS activation rejects user state not described declaratively. The flag, admin workspace tmpfiles rule, and the actual `root`, `admin`, and `hermes` user/SSH declarations are rendered from `den/entities.nix` through the Den host aspect. Do not add users imperatively on the host.
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
`checks.x86_64-linux.den-host-vm-smoke` boots a VM built from the
Den-modeled host/user facts and is the iteration harness for Den refactors:
when a host module is migrated into a Den aspect, add VM-safe assertions there
before using the live host as evidence. `checks.x86_64-linux.vm-switch-smoke`
is the heaviest repo-owned smoke: it boots a VM, switches to a prebuilt target
system inside the guest with `switch-to-configuration switch`, and verifies
`/etc` plus `/run/current-system` moved. Use it when build/dry-activate proof
is not enough for activation or switch-time behavior. It intentionally does not
exercise guest-side `nixos-rebuild` flake evaluation or network/cache access.
VM tests are the right tool when activation scripts change, Den-rendered
behavior changes, or other build-only proof is insufficient.
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
      override in `den/hosts/nixos-hermes/services/netdata.nix` because both pinned nixpkgs inputs
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
- Checks that assert on Den inventory/model shape may additionally take
  `denModel`; they must distinguish model-shape assertions from rendered
  deployment behavior.
- These are evaluation/build checks, **not** VM tests — they sit alongside the VM
  suite in `tests/` but never boot a guest. Run one with
  `nix build .#checks.x86_64-linux.<name>`.
- Path literals inside a check resolve relative to the file, so reference repo
  paths as `../../packages/...`, `../../hosts/...`, etc. — not `./...`.

### `den/`

*Den model and rendered baseline output for the homelab graph.*

- Reviewers new to this branch should start with root `REVIEW.md` for the
  factual technical overview and root `ARCHITECTURE.md` for the target Den
  architecture direction.
- `nixosConfigurations.nixos-hermes` remains the deployment output, but it now
  imports `self.denModel.den.hosts.x86_64-linux.nixos-hermes.mainModule`.
  Den-rendered NixOS/Home Manager output owns migrated baseline config.
- `schema.nix` owns repo-local host/user vocabulary mirrored from current code,
  such as imported module paths, service-module lists, `stateVersion`,
  `nixpkgsHostPlatform`, host identity, baseline system packages, user homes,
  groups, Home Manager presence, and SSH keys. Do not add aspirational/persona
  fields here unless an existing source file already encodes that fact.
- `entities.nix` owns current repo-safe inventory facts for `nixos-hermes`,
  `root`, `admin`, `hermes`, and VM fixture user `den-poc`. It also owns the
  Den aspects that render the migrated system baseline, user declarations, SSH
  keys, and `admin`/`hermes` Home Manager config. Keep entities inventory-like;
  extract reusable behavior into `lab.*` as it grows.
- `lab.nix` owns the local `lab` namespace/category skeleton. Reusable behavior
  should later land under `lab.platform`, `lab.features`, `lab.workloads`,
  `lab.hardware`, `lab.users`, or `lab.quirks`; concrete host/user aspects should
  stay thin composition points.
- Do not add custom fleet/environment topology, quirks that drive production
  config, or host-service migrations here without a follow-up issue and eval/VM
  proof. Current Den-rendered production scope is users, SSH keys, Home Manager,
  host/system baseline, hardware, SOPS/secrets, virtualization, provisioning, user-management, Home Manager integration, users/Home Manager, and install-time
  Disko path facts. Disko/ZFS layout and package overlay
  definitions, and service runtime modules remain native host imports.

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

### Host module graph

The host no longer has a `hosts/hermes/default.nix` entrypoint. `flake.nix`
maps `den.hosts.x86_64-linux.nixos-hermes.moduleImports` into the NixOS module
list. The Den host entity categorizes that graph as hardware, storage, secrets,
platform, service, and shared modules.

- Do not re-add a host entrypoint import list under `hosts/hermes/default.nix`.
- Add new host module files to the appropriate Den host graph category in
  `den/entities.nix`, then extend eval/VM proof where the module has
  VM-safe behavior.

### Den hardware facts

*Bare-metal hardware configuration rendered from Den.*

- Facts live under `den.hosts.x86_64-linux.nixos-hermes.hardware`.
- `den.aspects.nixos-hermes.os` renders boot, initrd, kernel, GPU, bootloader, fallback ESP sync, and ZFS maintenance settings.
- Storage layout remains in `den/hosts/nixos-hermes/storage/disk-config.nix`; hardware facts do not repartition disks.
- Filesystem mounts themselves are generated by `disko` from `disk-config.nix`, not declared here.

### `den/hosts/nixos-hermes/storage/disk-config.nix`

*Declarative disk layout consumed by `disko`.*

- Describes GPT partitions and the ZFS pool/dataset structure.
- Imported as a NixOS module via `disko.nixosModules.default`, so `disko` generates `fileSystems.*` entries at evaluation time from the `mountpoint = "..."` attributes on each partition and dataset.

> Do not declare `fileSystems.*` manually in `hardware.nix` — that would duplicate what `disko` produces.

At install time:
  - The same Den-declared path is also consumed by `nix run .#disko-hermes`.
  - Exposed as a flake app so the CLI uses the same `flake.lock` pin as the NixOS module, eliminating module/CLI version skew.

After first install:
  - The partition/pool sections are effectively reference documentation.
  - Changing them does not reformat disks, but the `mountpoint` attributes remain live: they control mounting on every rebuild.

### Den secret facts

*Maps SOPS-encrypted files to runtime paths from Den.*

- Facts live under `den.hosts.x86_64-linux.nixos-hermes.secrets`.
- `den.aspects.nixos-hermes.os` renders `sops.defaultSopsFile`, age identity settings, and `sops.secrets`.
- Committed encrypted payloads live under `den/hosts/nixos-hermes/secrets/payload/`.

- The `sops age` key path (`/etc/secrets/age.key`) is modeled by Den and must not change without updating the host secret facts.

### Den platform virtualisation facts

*Host-local Docker/libvirt substrate rendered from Den.*

- Facts live under `den.hosts.x86_64-linux.nixos-hermes.platform.virtualisation`.
- `den.aspects.nixos-hermes.os` renders Docker, libvirt/QEMU, virtiofsd registration, packages, and host-specific operator group memberships needed to use those services.
- Keep Docker/libvirt group membership facts in the platform virtualisation surface, not in generic user facts, because those groups only exist on hosts that enable the corresponding services.
- Docker group access is root-equivalent on this host. Adding `hermes` to `docker` is a deliberate operational trust decision for container-first workload proving, not a sandbox boundary.
- The Docker ZFS storage driver is for the bare-metal ZFS host only. Guest Docker inside VMs/microVMs should use overlay2 on ext4/xfs to avoid stacked CoW over host ZFS.

### Den provisioning facts

*Host-specific activation scripts rendered from Den.*

- Facts live under `den.hosts.x86_64-linux.nixos-hermes.platform.provisioning`.
- `den.aspects.nixos-hermes.os` renders one-shot SOUL.md seeding and recurring GitHub credential refresh.
- **One-shot provisioning:** activation scripts with a file-existence guard run once on first boot to seed runtime state. Rebuilds do not clobber runtime-evolved state. To re-provision: delete the target file on the host, then rebuild.
- **Recurring refresh:** activation scripts with no guard run on every activation. Used for credentials and other state that must stay in sync with sops secrets.
- These facts are host-specific and not portable across hosts.
- To re-provision a file: delete it on the host, then rebuild.

### `den/hosts/nixos-hermes/shared/packages.nix`

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

### Den shared system, Home Manager, and user-management facts

*Shared baseline rendered from Den.*

- The former `shared/system.nix`, `shared/home-manager.nix`, and
  `shared/users.nix` marker modules have been removed.
- Locale, timezone, networking, OpenSSH, sudo, Home Manager integration flags,
  immutable-user policy, admin workspace tmpfiles, users, SSH keys, packages,
  and session variables are rendered from `den/entities.nix` via the Den host
  aspect.
- Keep new user-facing toolchain changes in the Den user/home aspects unless
  intentionally changing this ownership boundary.
- Add other service accounts deliberately; review their runtime state boundary
  before Home Manager owns additional home files.

### `den/hosts/nixos-hermes/services/hermes-agent/default.nix`

*The `hermes-agent` service declaration.*

- All core `services.hermes-agent.*` options belong here.
- Secrets are referenced by name from the `sops` bindings.

### `den/hosts/nixos-hermes/services/hermes-agent/plugins.nix`

*Declarative Hermes plugin installation and enablement.*

- Entry-point Python plugins belong in `services.hermes-agent.extraPythonPackages`.
- Directory plugins belong in `services.hermes-agent.extraPlugins`.
- Plugin runtime binaries belong in `services.hermes-agent.extraPackages`.
- Plugin names must also be enabled in `services.hermes-agent.settings.plugins.enabled`.
- See `docs/guides/HERMES_PLUGINS_NIX.md` before adding or updating plugins.

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
