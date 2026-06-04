# Den Review Guide for Nix Maintainers

This guide is the durable reviewer entrypoint for Den-shaped infrastructure work in this repo. It assumes you are comfortable reviewing Nix flakes/modules but have not internalized Den yet.

For the target architecture, read `docs/guides/DEN_HOMELAB_ARCHITECTURE.md`. This file is narrower: it explains how to review the repo as it migrates into Den.

## One-sentence model

Den turns a Nix flake from “host files directly assemble outputs” into a graph model:

- **entities** say what exists;
- **aspects** say what behavior can be composed;
- **policies** say how scopes are traversed and outputs are instantiated;
- **quirks/pipes** move structured operational facts between producers and consumers.

In ordinary Nix terms: Den is a module-system-powered graph/routing layer above NixOS, Home Manager, flake-parts, and other output classes.

## Current repo phase

The current `den/` tree is an **eval-only model surface**.

It is not the deployment output. The live host is still built by:

```nix
nixosConfigurations.nixos-hermes
```

Den is currently used to model and check inventory shape before it owns host rendering. Treat any change that makes Den drive production NixOS/Home Manager config as a later milestone unless the issue explicitly says otherwise.

## Files to review first

For Den-related changes, review in this order:

1. `docs/guides/DEN_REVIEW_GUIDE.md` — this reviewer contract.
2. `docs/guides/DEN_HOMELAB_ARCHITECTURE.md` — target architecture and migration rules.
3. `AGENTS.md` sections for `den/` and `tests/eval/` — repo ownership rules.
4. `flake.nix` — input pins and output wiring only.
5. `den/default.nix` — Den model module entrypoint.
6. `den/schema.nix` — repo-local vocabulary/types.
7. `den/entities.nix` — current host/user facts.
8. `den/lab.nix` — local reusable namespace skeleton.
9. `tests/eval/den-model-surface.nix` — executable assertions proving the model shape.

If a PR changes Den behavior but not the matching check or docs, ask why.

## Review checklist

### Boundary checks

- [ ] `nixosConfigurations.nixos-hermes` remains the live deployment output unless the issue explicitly changes that boundary.
- [ ] `denModel` stays eval-only and is validated through `checks.x86_64-linux.den-model-surface` or a similarly named check.
- [ ] `flake.nix` stays thin: input pins + output wiring, not Den logic.
- [ ] New substantial Den logic lives under `den/`, `tests/eval/`, or docs — not inline in `flake.nix`.

### Schema/entity checks

- [ ] Facts about what exists belong in `den/entities.nix` or schema-owned fields.
- [ ] Reusable vocabulary belongs in `den/schema.nix` with typed options.
- [ ] First-slice schema/entity fields mirror existing source files. Do not add persona, topology, role, or future-state vocabulary unless an existing repo file already encodes that fact.
- [ ] Entity declarations remain fact-like. They should not become long NixOS/Home Manager modules.
- [ ] New fields have a reason to be schema, not random freeform metadata.
- [ ] Sensitive details are not introduced as public inventory facts.

### Aspect/API checks

- [ ] Reusable behavior goes under the local `lab` namespace (`lab.roles`, `lab.features`, `lab.workloads`, `lab.hardware`, `lab.platform`, `lab.users`, `lab.quirks`).
- [ ] Concrete host/user aspects stay thin composition points.
- [ ] New code uses `den.batteries.*`, not legacy `den.provides` / `den._` in new docs or implementation.
- [ ] New code avoids centering legacy/internal APIs such as `den.ctx`, `den.lib.parametric`, `perHost`/`perUser`, or direct `den.lib.aspects.resolve` unless the PR explains why.

### Policy/topology checks

- [ ] First-slice work uses default Den host/home traversal policies.
- [ ] Custom topology is added only with an explicit issue and checks that prove default policies are not duplicating output instantiation.
- [ ] `site`, `environment`, and `workloads` stay host schema fields until promotion to first-class entities is justified by routing, scoped pipe collection, generated docs, or output instantiation.

### Quirk/pipe checks

- [ ] Quirks/pipes do not drive production config until local payload constructors/assertions exist.
- [ ] Operational lists should move toward “producers emit structured data; collectors assemble it,” not global lists edited from many places.

### Validation checks

- [ ] Den model changes include or update a pure eval check.
- [ ] `nix flake check --no-build` passes for structural changes.
- [ ] A targeted check such as `nix build .#checks.x86_64-linux.den-model-surface` passes when the Den model shape changes.
- [ ] Host-output safety is shown with at least `nix eval .#nixosConfigurations.nixos-hermes.config.system.build.toplevel.drvPath` unless the change is docs-only.

## Common review traps

### Trap: treating Den entities as implementation modules

Bad smell:

```nix
den.hosts.x86_64-linux.nixos-hermes = {
  services.openssh.enable = true;
  services.hermes-agent.enable = true;
  # ...many lines of NixOS config...
};
```

Better shape:

```nix
den.hosts.x86_64-linux.nixos-hermes = {
  role = "agent-host";
  workloads = [ "hermes-agent" "netdata" ];
};

den.aspects.nixos-hermes.includes = [
  lab.roles.agent-host
  lab.workloads.hermes-agent
  lab.workloads.netdata
];
```

Facts live on entities; behavior lives in aspects.

### Trap: hiding a deployment migration inside “modeling”

Adding `denModel` or schema is modeling. Changing `nixosConfigurations.nixos-hermes` to be generated from Den is deployment-shape work. That requires a separate issue, explicit validation ladder, and likely dry-build/VM/live-host planning.

### Trap: over-modeling too early

Do not promote `site`, `environment`, or `workload` to first-class Den entities just because the architecture doc says the long-term graph can support it. Promotion is useful when the concept needs routing, scoped collection, generated docs, or output instantiation.

### Trap: using PR comments as the only explanation

Den will become the repo shape. Reviewer context belongs in source-controlled docs and AGENTS guidance, not only in ephemeral PR bodies or Linear comments.

## Current expected commands

For model-shape changes:

```bash
nix flake check --no-build
nix eval .#nixosConfigurations.nixos-hermes.config.system.build.toplevel.drvPath
nix build .#checks.x86_64-linux.den-model-surface
```

For docs-only changes, pre-commit is normally enough, but if docs alter review/architecture rules that affect Nix ownership, run the relevant eval checks anyway when practical.

## Maintaining this guide

Update this file when:

- Den becomes the source of a production output;
- a new `lab.*` category gains real behavior;
- custom topology or quirk/pipeline routing is introduced;
- reviewers ask the same Den question twice;
- a validation check changes what reviewers should trust.

If this guide drifts, reviewers will either rubber-stamp unfamiliar abstractions or block on Den vocabulary instead of reviewing the actual Nix design. Neither is acceptable.
