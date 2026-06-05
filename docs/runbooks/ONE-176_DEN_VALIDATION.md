# ONE-176 Den Migration Validation Report

## Scope

This report records the local evidence for the repo-wide Den migration branch. It distinguishes VM/build proof from live-runtime proof. A green VM does not mean every production daemon is running cleanly on real hardware.

Branch under validation:

```text
yui/ONE-176-den-repo-shape
```

Latest validated head observed locally:

```text
9abe6888be8f230dce67edc46b66696ee291d0c2
```

## Validation summary

| Boundary | Command / probe | Result | Claim proved |
| --- | --- | --- | --- |
| VM-safe Den host rendering | `nix build .#checks.x86_64-linux.den-host-vm-smoke --no-link --no-eval-cache -L` | PASS | Den-rendered host/user/HM shape boots in a VM and satisfies the checked assertions. |
| Real host closure build | `nix build .#nixosConfigurations.nixos-hermes.config.system.build.toplevel --no-link --no-eval-cache -L` | PASS | The real `nixos-hermes` system closure builds from Den-rendered configuration. |
| Full flake eval surface | `nix flake check --no-build` | PASS in prior branch validation | All repo checks evaluate; VM derivations are not run by this command. |

## Den VM smoke assertions

The `den-host-vm-smoke` VM currently proves:

- guest reaches `multi-user.target`;
- hostname is `nixos-hermes`;
- `admin`, `hermes`, and `den-poc` users exist;
- `admin` has expected group membership;
- `/home/admin` exists with mode `700`;
- exact Den-declared SSH key sets are present for `root`, `admin`, and `hermes`;
- Home Manager is active for `admin`;
- admin tools run from `/etc/profiles/per-user/admin/bin`:
  - `glow`
  - `bat`
  - `yazi` under a pseudo-terminal
  - `omp`
- `den-poc` proves mixed Den-rendered plus native Home Manager package activation for the same user.

## Known VM non-claims

The VM deliberately does not prove:

- real Disko partitioning or ZFS pool import on the bare-metal NVMe devices;
- real SOPS secret decryption with `/etc/secrets/age.key`;
- Netdata Cloud claim/enrollment state;
- Hermes provider authentication or external model routing;
- Agent Memory LLM behavior through OMP/CLIProxyAPI;
- OMP auth gateway runtime behavior;
- persistent service state under `/var/lib/*`;
- live activation behavior on the real host.

Docker is not a clean VM-runtime claim for this test. The host config selects Docker's ZFS graph driver for bare metal, while the VM runs on an ext4 test disk. The observed VM log includes Docker startup failure with:

```text
failed to start daemon: error initializing graphdriver: prerequisites for driver not satisfied (wrong filesystem?): zfs
```

That does not invalidate the current VM assertions, but it means the VM report must not say “everything is running cleanly.” It says the asserted Den-rendered surfaces passed.

## Production follow-up gates

Before persistent deployment, use the repo deployment ladder:

1. Validate from a clean checkout with only the target branch applied.
2. Take a ZFS recovery snapshot on the host immediately before live activation.
3. Run `sudo nixos-rebuild test --flake .#nixos-hermes -L` for temporary activation.
4. Run service-specific runtime smokes:
   - Netdata local API and Cloud claim/status API;
   - Hermes service health and model/provider routing;
   - OMP auth gateway `/v1/models` and chat smoke;
   - Agent Memory health, Hermes MCP/provider checks, and `tools/agentmemory-llm-smoke.sh --timeout 180`;
   - Hindsight continuity smoke only if Hindsight wiring is enabled or changed.
5. Open/review/merge the PR after local host validation.
6. Wait for CI and FlakeHub publication.
7. Run persistent `nixos-rebuild switch` from the published remote flake unless an operator explicitly authorizes a local switch.
