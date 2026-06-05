# REVIEW.md — Technical Overview for Reviewers

This repository is a NixOS flake for the bare-metal `nixos-hermes` host. The host runs Hermes Agent and adjacent local services as a declarative NixOS system.

This document is factual orientation: what is wired where, what Den currently renders, what remains outside Den, and which checks prove which claims.

## Main deployment output

The live NixOS system is built from:

```nix
nixosConfigurations.nixos-hermes
```

In `flake.nix`, that output is assembled with `nixpkgs.lib.nixosSystem`. Its `system` comes from the Den host fact:

```nix
self.denModel.den.hosts.x86_64-linux.nixos-hermes.nixpkgsHostPlatform
```

Its module list includes the Den-rendered host module:

```nix
self.denModel.den.hosts.x86_64-linux.nixos-hermes.mainModule
```

The real-host Disko module is added at the flake boundary from Den storage facts so the host has `disko.devices` while VM tests that omit the Disko module do not evaluate nonexistent options.

Den is not a separate deployment output. Den contributes rendered NixOS/Home Manager configuration into the normal NixOS deployment output.

## Den model surface

Den is pinned as:

```nix
den.url = "github:denful/den/v0.17.0";
```

The repo-local Den entrypoint is `den/default.nix`, which imports:

- `den/schema.nix`
- `den/entities.nix`
- `den/lab.nix`

The evaluated model is exposed as:

```nix
denModel
```

## What Den renders today

`den/entities.nix` owns the source facts and render aspects for the production host shape.

Den-rendered production scope:

- host identity:
  - `networking.hostName`
  - `networking.hostId`
  - `system.stateVersion`
  - `nixpkgsHostPlatform`
- hardware and boot:
  - kernel modules and parameters
  - initrd modules
  - bootloader and fallback ESP sync
  - firmware, microcode, graphics packages
  - ZFS scrub/trim maintenance
- storage:
  - Disko device/pool/dataset facts
  - host Disko rendering in `flake.nix`
  - `disko-hermes` app rendering in `apps/default.nix`
- system baseline:
  - timezone
  - default locale
  - console keymap
  - Nix trusted users
  - NetworkManager enablement
  - firewall disabled
  - power/thermal/printing/video baseline
  - OpenSSH enablement and host key declaration
  - D-Bus implementation pin
  - passwordless wheel sudo
  - baseline `environment.systemPackages`
  - `LIBVA_DRIVER_NAME`
- SOPS secrets:
  - default SOPS file
  - age identity settings
  - declared secret bindings and runtime paths
  - committed encrypted payload references
- platform substrate:
  - Docker/libvirt enablement
  - Docker ZFS storage driver for the bare-metal host
  - QEMU/libvirt packages and operator groups
- provisioning:
  - one-shot SOUL.md seed
  - recurring GitHub credential refresh
- users and SSH keys:
  - `root`
  - `admin`
  - `hermes`
- Home Manager users:
  - `admin`
  - `hermes`
- runtime services:
  - Hermes Agent base service and runtime settings
  - Hermes plugins and Python extras
  - Netdata monitoring and MCP wiring
  - Agent Memory service and Hermes MCP/provider wiring
  - OMP auth gateway
  - Hindsight memory options remain modeled but disabled
- package overlays and host package workarounds:
  - community/fast-moving package overlays
  - `opusCtypesShim`
  - Repowise/Vite+/CLIProxyAPI wrappers
- VM-only migration fixture:
  - `den-poc`

The concrete Den render aspect is:

```nix
den.aspects.nixos-hermes.os
```

That aspect emits NixOS and Home Manager options consumed by the host output.

## What remains outside Den

The native host module leaves formerly under `hosts/`, `modules/`, and `den/hosts/nixos-hermes/{hardware,platform,services,shared,storage}` have been removed. `den/hosts/nixos-hermes/` now contains only committed SOPS-encrypted payloads.

The remaining non-Den surfaces are intentional boundaries:

- flake input/output wiring in `flake.nix`;
- app wrapper definitions in `apps/default.nix`;
- checks and VM tests under `tests/`;
- package sources under `packages/`;
- committed encrypted secret payloads under `den/hosts/nixos-hermes/secrets/payload/`;
- runtime data on the host, such as model files, service databases, and Netdata Cloud enrollment state.

## Current ownership

### `den/schema.nix`

Owns repo-local vocabulary for host, user, Home Manager, hardware, storage, secrets, platform, services, package overlays, and VM migration fixtures. The schema mirrors current repository facts; it is not a future topology plan.

### `den/entities.nix`

Owns the `nixos-hermes` host facts and the aspect that renders those facts into NixOS/Home Manager configuration. New host-owned configuration should start here unless there is a concrete boundary reason it cannot be modeled as Den facts.

### `apps/default.nix`

Owns flake apps and renders `disko-hermes` from Den storage facts. This keeps install-time Disko and the NixOS module using the same modeled storage source.

### `flake.nix`

Owns flake inputs, output wiring, platform boundaries, and the final host module list. It renders Disko devices from Den facts only for the real host output where the Disko module is imported.

## Tests and checks

### Pure Den model check

```bash
nix build .#checks.x86_64-linux.den-model-surface
```

This checks Den inventory/model facts without booting a VM.

### Den VM smoke

```bash
nix build .#checks.x86_64-linux.den-host-vm-smoke
```

This boots a NixOS VM from Den-rendered host facts and asserts VM-safe rendered behavior.

Current VM assertions include:

- boot reaches `multi-user.target`;
- hostname is `nixos-hermes`;
- `admin`, `hermes`, and `den-poc` users exist;
- `admin` group membership includes expected groups;
- `/home/admin` exists with mode `700`;
- exact Den-declared SSH key sets are present for `root`, `admin`, and `hermes`;
- Home Manager activation is active for `admin`;
- admin tools run from the HM profile:
  - `glow`
  - `bat`
  - `yazi` under a pseudo-terminal
  - `omp`
- same-user mixed migration is still proven through `den-poc` with Den-rendered and native HM packages together.

The VM intentionally does not prove real hardware, real Disko/ZFS layout activation, real SOPS secret decryption, cloud enrollment, persistent service state, or live service authentication. Docker is not a VM-clean claim here: the VM uses an ext4 disk while the host config selects Docker's ZFS graph driver, so Docker can fail in this VM without invalidating the asserted Den migration surface.

### Host toplevel build

```bash
nix build .#nixosConfigurations.nixos-hermes.config.system.build.toplevel
```

This builds the real host system closure with Den-rendered configuration.

### Full structural flake check

```bash
nix flake check --no-build
```

This evaluates apps, checks, formatter, devShells, and the NixOS configuration without building every output. It does not run VM tests.

## Live-host validation boundary

The branch-level checks prove evaluation, package resolution, VM-safe Den rendering, and host closure build.

They do not activate the real machine. Live activation remains a separate operator step. For this repo, the expected path before persistent switch is:

1. take a ZFS recovery snapshot on the host;
2. run local `nixos-rebuild test --flake .#nixos-hermes -L` from a clean checkout;
3. inspect service health and runtime-specific proof;
4. open/review/merge the PR after local validation;
5. wait for CI and FlakeHub publication;
6. run persistent `nixos-rebuild switch` from the published remote flake unless explicitly authorizing a local switch.

Runtime service proof after activation should include the relevant service-specific smokes, especially Netdata claim/API state, Agent Memory/Hermes MCP/provider checks, OMP gateway model listing, and any Hindsight continuity smoke if Hindsight wiring changes.

## Reviewer starting points

For a Den-related review, useful files are:

1. `REVIEW.md` — this technical overview.
2. `flake.nix` — deployment output wiring and check wiring.
3. `den/schema.nix` — repo-local Den vocabulary.
4. `den/entities.nix` — migrated facts and render aspects.
5. `apps/default.nix` — Den-rendered Disko app and operational wrappers.
6. `tests/eval/den-model-surface.nix` — pure model assertions.
7. `tests/default.nix` — VM assertions.
8. `AGENTS.md` — agent-facing ownership and operational rules.
9. `ARCHITECTURE.md` — Den architecture vocabulary and direction.
