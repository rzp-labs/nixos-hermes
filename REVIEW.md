# REVIEW.md — Technical Overview for Reviewers

This repository is a NixOS flake for the bare-metal `nixos-hermes` host. The host runs Hermes Agent and adjacent local services as a declarative NixOS system.

This document is factual orientation: what is wired where, what Den currently renders, what remains native NixOS, and which checks prove which claims.

## Main deployment output

The live NixOS system is built from:

```nix
nixosConfigurations.nixos-hermes
```

In `flake.nix`, that output is assembled with `nixpkgs.lib.nixosSystem`. Its `system` comes from the Den host fact:

```nix
self.denModel.den.hosts.x86_64-linux.nixos-hermes.nixpkgsHostPlatform
```

Its module list includes the Den-rendered host module first, followed by the
Den-owned flattened host module graph:

```nix
self.denModel.den.hosts.x86_64-linux.nixos-hermes.mainModule
++ map (path: ./. + "/${path}") self.denModel.den.hosts.x86_64-linux.nixos-hermes.moduleImports
```

So Den is not a separate deployment output. Den contributes rendered NixOS/Home Manager configuration into the normal NixOS deployment output.

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

`den/entities.nix` currently owns the source facts and render aspects for migrated baseline configuration.

Den-rendered production scope:

- host identity:
  - `networking.hostName`
  - `networking.hostId`
  - `system.stateVersion`
  - `nixpkgsHostPlatform`
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
- users and SSH keys:
  - `root`
  - `admin`
  - `hermes`
- Home Manager users:
  - `admin`
  - `hermes`
- VM-only migration fixture:
  - `den-poc`

The concrete Den render aspect is:

```nix
den.aspects.nixos-hermes.os
```

That aspect emits NixOS and Home Manager options consumed by the host output.

## Native NixOS modules selected by Den

The following files remain native NixOS modules, but their inclusion is now
selected by the Den host graph in `den/entities.nix`. There is no longer a
`hosts/hermes/default.nix` entrypoint controlling the host import list.

- hardware, boot, kernel, GPU, and ZFS service options:
  - `hosts/hermes/hardware.nix`
- Disko/ZFS layout:
  - `hosts/hermes/disk-config.nix`
- SOPS secret bindings:
  - `hosts/hermes/sops.nix`
- host activation/provisioning scripts:
  - `hosts/hermes/provision.nix`
- Docker/libvirt substrate:
  - `hosts/hermes/virtualisation.nix`
- runtime service modules:
  - `hosts/hermes/llama-server.nix`
  - `hosts/hermes/hindsight-embed.nix`
  - `hosts/hermes/hindsight-memory.nix`
  - `hosts/hermes/agentmemory.nix`
  - `hosts/hermes/netdata.nix`
  - `hosts/hermes/omp-auth-gateway.nix`
  - `modules/hermes-agent.nix`
  - `modules/hermes-plugins.nix`
- package overlays and host package workarounds:
  - `modules/packages.nix`

## Current module ownership

### `den/entities.nix`

Owns the host module graph categories used by `flake.nix`:

- `hardwareModules`
- `storageModules`
- `secretModules`
- `platformModules`
- `serviceModules`
- `sharedModules`
- flattened `moduleImports`

This is the current host instantiation boundary: `flake.nix` maps these Den
paths into NixOS modules.

### `modules/system.nix`

Marker module only. Migrated baseline system settings are rendered from Den.

### `modules/home-manager.nix`

Home Manager NixOS integration flags only:

```nix
home-manager.useGlobalPkgs = true;
home-manager.useUserPackages = true;
```

User Home Manager configs are rendered from Den.

### `modules/users.nix`

Immutable-user policy and an admin workspace tmpfiles rule:

```nix
users.mutableUsers = false;
systemd.tmpfiles.rules = [
  "d /home/admin/workspace 0755 admin users - -"
];
```

Actual user accounts and SSH keys are rendered from Den.

### `modules/packages.nix`

Owns overlays and package workarounds. The Den VM uses the real host `pkgs` instance from `nixosConfigurations.nixos-hermes.pkgs`, so Den-rendered package names are resolved against the same package namespace as the host.

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

The VM intentionally does not prove real hardware, real SOPS secrets, cloud enrollment, persistent service state, or live service authentication.

### Host toplevel build

```bash
nix build .#nixosConfigurations.nixos-hermes.config.system.build.toplevel
```

This builds the real host system closure with the Den-rendered baseline and the
Den-selected native module graph.

### Full structural flake check

```bash
nix flake check --no-build
```

This evaluates apps, checks, formatter, devShells, and the NixOS configuration without building every output.

## Live-host validation boundary

The branch-level checks prove evaluation, package resolution, VM-safe Den rendering, and host closure build.

They do not activate the real machine. Live activation remains a separate operator step. For this repo, the expected path before persistent switch is:

1. take a ZFS recovery snapshot on the host;
2. run local `nixos-rebuild test --flake .#nixos-hermes -L` from a clean checkout;
3. inspect service health and runtime-specific proof;
4. only then consider persistent switch through the published flake path.

## Reviewer starting points

For a Den-related review, useful files are:

1. `REVIEW.md` — this technical overview.
2. `flake.nix` — deployment output wiring and check wiring.
3. `den/schema.nix` — repo-local Den vocabulary.
4. `den/entities.nix` — migrated facts and render aspects.
5. `tests/eval/den-model-surface.nix` — pure model assertions.
6. `tests/default.nix` — VM assertions.
7. `AGENTS.md` — agent-facing ownership and operational rules.
8. `ARCHITECTURE.md` — Den architecture vocabulary and direction.
