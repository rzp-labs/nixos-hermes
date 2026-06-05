# nixos-hermes

NixOS configuration for **hermes** — a dedicated bare-metal host for running
[NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) as a
personal, always-on AI assistant.

Secondary goals: learn NixOS/Nix as a discipline and leave room to run
multiple agents concurrently as capabilities grow.

---

## Hardware

| Component | Spec                                                   |
|-----------|--------------------------------------------------------|
| Host | HP Elite Mini 800 G9                                   |
| CPU | Intel Core i5-14500T (14-core, Raptor Lake)            |
| RAM | 96GB DDR5-5600                                         |
| Storage | 2 × 2TB Samsung 990 Pro NVMe SSD (ZFS mirror)          |
| GPU | None (Intel Arc iGPU only, Quick Sync / VA-API enabled) |

---

## Architecture

### Storage

ZFS mirror pool (`rpool`) spanning both NVMe drives. Dataset layout:

```text
rpool
├── root/nixos      → /                 (legacy mount, OS root)
├── nix             → /nix              (zstd, Nix store)
├── var             → /var              (runtime state)
└── data
    ├── hermes      → /var/lib/hermes   (16K recordsize, agent home)
    └── backup      → /data/backup      (zstd, 1M records, atime off)
```

Each NVMe also carries a 1GB FAT32 ESP. The primary ESP mounts at `/boot`;
the secondary at `/boot-fallback`. On every `nixos-rebuild switch`, systemd-boot
replicates the primary ESP to the fallback via `rsync`.

ZFS ARC is capped at 16GB to leave headroom for the agent workload.

Disk layout, partitioning, and the generated `fileSystems.*` entries are
modeled as Den storage facts in `den/schema.nix` / `den/entities.nix`. The
flake renders those facts into the [disko](https://github.com/nix-community/disko)
NixOS module and the `disko-hermes` app from the same source of truth.

### Secrets Management

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) and
[age](https://github.com/FiloSottile/age). The age host key lives at
`/etc/secrets/age.key` (generated once, placed manually during bootstrap).
Encrypted secrets live under `den/hosts/nixos-hermes/secrets/payload/` and are decrypted at activation
time.

### Hermes Agent

Declared via the official `hermes-agent.nixosModules.default` NixOS module,
sourced from `github:NousResearch/hermes-agent`. Agent state persists in
`rpool/data/hermes` (mounted at `/var/lib/hermes`). The `HERMES_HOME`
environment variable points into that dataset.

---

## Network

| Property | Value |
|----------|-------|
| Hostname | `nixos-hermes` |
| IP | Static, gateway-enforced (subject to change) |
| Firewall | Disabled — the network perimeter is trusted |

The specific IP is not hardcoded in this configuration and is managed at the
gateway. Update your SSH config when it changes.

---

## Repository Layout

```text
nixos-hermes/
├── flake.nix                          # Thin manifest: inputs/outputs, host definition, wiring
├── checks/pre-commit.nix              # git-hooks.nix hook config (dev shell + pre-commit-check)
├── apps/default.nix                   # flake apps: nixos-anywhere, disko, smoke wrappers
├── tests/                             # VM tests (tests/default.nix) + eval checks (tests/eval/)
├── .github/workflows/flakehub-publish-rolling.yml  # CI: publish to FlakeHub on push to main
├── .sops.yaml                         # sops encryption rules (age keys)
├── .secrets/                          # gitignored — plaintext secrets (local only)
│   └── hermes-secrets.yaml            # template; encrypt before committing
└── den/
    ├── default.nix                    # Den model entrypoint
    ├── schema.nix                     # repo-local host/user/service/storage schema
    ├── entities.nix                   # host facts and render aspects
    ├── lab.nix                        # local lab namespace/category skeleton
    └── hosts/nixos-hermes/secrets/payload/ # committed SOPS-encrypted payloads
```

---

## Local Development

Contributor tooling is provided by a dedicated `shell.nix` used by the flake:

```nix
{
  devShells.${system}.default = import ./shell.nix { inherit pkgs hooks; };
}
```

The shell includes:

- Pre-commit hook packages (`hooks.enabledPackages` when hooks are available)
- `sops`
- `prek`
- `nixd`
- `nil`
- `alejandra`
- `statix`
- `deadnix`

### direnv and auto-loading

To keep the shell loaded automatically when entering the repository, install
`direnv` and `nix-direnv`, then use:

```bash
direnv allow
```

This repository ships `.envrc` with `use flake`, so `direnv` will enter the same
development shell automatically on both macOS and Linux.

---

## Bootstrapping the Host

Two supported paths. Prefer **nixos-anywhere** for a headless remote install;
fall back to the **Live CD** flow only when SSH to the target is unavailable.

### Prerequisites

The target must be reachable over SSH as `root` (or a passwordless-sudo user)
from your workstation, running any modern Linux kernel. Prep depends on the
target's starting state:

- **Already running Linux (any distro):** confirm `sshd` is up, your key is in
  `~/.ssh/authorized_keys`, and the machine has outbound internet. Nothing else
  to install — nixos-anywhere will kexec over it.
- **Bare-metal, no OS (e.g. a fresh hermes host):** boot any NixOS live ISO
  (minimal or Determinate Nix). Two routes:
  - *USB:* write the ISO, plug in monitor + keyboard once, set a root
    password, `ssh-copy-id` from your workstation, unplug and finish
    headlessly.
  - *Intel vPro / AMT IDE-R (fully remote):* after a one-time MEBx setup
    (`Ctrl-P` at POST), use MeshCommander/MeshCentral to mount the ISO
    remotely and authorize SSH through the AMT KVM. No USB or monitor on
    the target ever after that.
- **Has dedicated IPMI/BMC with remote media:** mount a Linux rescue ISO via
  the BMC web UI. Not applicable to the hermes host (vPro/AMT is the
  equivalent — see above).

From your workstation, with an age private key available locally:

```bash
mkdir -p extra-files/etc/secrets
cp /path/to/age.key extra-files/etc/secrets/age.key
chmod 400 extra-files/etc/secrets/age.key

nix run .#nixos-anywhere -- \
  --flake .#nixos-hermes \
  --extra-files extra-files \
  root@<target>

find extra-files -type f -exec shred -u {} +
rm -rf extra-files
```

This kexec's the target into the NixOS installer, runs Disko from the
Den-declared host storage facts to partition and mount, installs, and reboots.
The age key is seeded into `/etc/secrets/age.key` on the installed system so
sops-nix can decrypt secrets on first activation.

Full install instructions, including the Live CD fallback and the bootloader
workaround, live in [`AGENTS.md`](AGENTS.md#first-install).

---

## Applying the Changes

There is no automated deployment step yet. For host-affecting feature branches,
use the branch as a temporary validation artifact only; persistent switches use
the reviewed, merged, published remote flake unless an operator explicitly
authorizes otherwise:

1. Push the branch with `but push` so a remote flake ref exists for review and temporary validation.
2. Run local pre-host validation from a clean checkout: `nix flake check
   --no-build`, `nixos-rebuild dry-build`, and, for unit/runtime changes,
   `nixos-rebuild dry-activate`.
3. For release-line/channel bumps, treat the change as a runtime migration even
   when the handwritten diff is small: inspect critical option and systemd unit
   diffs, avoid implicit D-Bus implementation migration unless intentional, and
   take a recursive ZFS snapshot before the first live activation attempt.
4. Run `nixos-rebuild test` from the local checkout for fast live validation
   without changing the boot default.
5. Run the relevant local validation and post-test smoke checks; commit and push
   any fixes.
6. Open the PR once the pushed branch contains the validated local state.
7. After review, merge, CI, and FlakeHub publication, run persistent
   `nixos-rebuild switch` from the published remote flake path unless an
   operator explicitly authorizes a local or PR-branch switch.

```bash
ssh admin@nixos-hermes
nix flake check --no-build --no-eval-cache -L
nixos-rebuild dry-build --flake /var/lib/hermes/workspace/nixos-hermes#nixos-hermes -L
sudo nixos-rebuild dry-activate --flake /var/lib/hermes/workspace/nixos-hermes#nixos-hermes -L
sudo zfs snapshot -r rpool@pre-<change>-$(date -u +%Y%m%dT%H%M%SZ)
sudo nixos-rebuild test --flake /var/lib/hermes/workspace/nixos-hermes#nixos-hermes -L
sudo nixos-rebuild switch --flake github:rzp-labs/nixos-hermes#nixos-hermes -L
```

After the PR lands on `main`, future production rebuilds can use the canonical
mainline flake:

```bash
ssh admin@nixos-hermes
sudo nixos-rebuild switch --flake github:rzp-labs/nixos-hermes#nixos-hermes -L
```

---

## CI and Deployment Trust

Pull requests run **Pre-PR verification** on GitHub Actions. That workflow is a
mechanical prefilter: it runs the repo-owned check script on a fresh generic Nix
runner and permits builds during `nix flake check` so import-from-derivation
helpers are realized in the cold CI store. A green check proves the flake
evaluates, repo-owned checks build, and generated configuration invariants pass.

Contributor-facing flake outputs support both `x86_64-linux` and
`aarch64-darwin`. Keep platform-specific outputs explicit: Linux-only checks,
apps, imports, and wrapper derivations should be defined inside their
`x86_64-linux` guard, not in an outer `let` that relies on Nix laziness to avoid
Darwin evaluation. This keeps cross-platform intent obvious to reviewers and bot
checks.

It is not deployment proof. The production host uses the Determinate NixOS image
and has real hardware, secrets, mutable service state, and activation behavior
that GitHub's Ubuntu runner cannot exercise. Changes that touch activation,
systemd relationships, secrets, hardware, networking, or live services still need
the appropriate host/VM gate from `AGENTS.md` before they are treated as safe to
rebuild.

GitHub Actions also publishes the flake to FlakeHub on every push to `main` using
the [DeterminateSystems](https://determinate.systems/) stack. That publish job is
distribution plumbing, not a substitute for pre-PR validation. It requires one
repository secret: `FLAKEHUB_TOKEN` (set under Settings → Secrets and variables →
Actions).

---

## Design Decisions

Architectural decisions are documented as ADRs in [`docs/adr/`](docs/adr/).
