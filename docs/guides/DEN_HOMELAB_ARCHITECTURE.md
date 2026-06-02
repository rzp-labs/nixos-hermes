# Den Homelab Architecture

Review basis: Den `v0.17.0` / `latest` at `8f1a59448043677ac8bc7854348c1b8ee6889c0b`, released 2026-05-21. This document describes the target homelab model against Den 0.17.0 semantics, not the older pre-effect-core architecture.

Den owns the shape of the infrastructure model. The homelab is a semantic graph: typed entities describe what exists, aspects describe behavior, policies describe topology and output routing, and quirks/pipes move structured operational data between scopes. Host files are inventory, not implementation dumps.

## Den 0.17.0 Model

Den 0.17.0 has four primary configuration concerns:

| Concern | Purpose | Homelab use |
|---|---|---|
| Entity | Typed record for something that exists | hosts, users, standalone homes, environments, workloads, sites |
| Aspect | Composable behavior | roles, features, workloads, hardware/platform bundles |
| Policy | Graph traversal, inclusion, routing, instantiation | flake → environment → host → user, host → workload, collectors |
| Quirk | Named operational data stream | monitoring targets, DNS records, proxy backends, backups |

The public framework surface is:

- `den.hosts.<system>.<name>` for host entities.
- `den.homes.<system>.<name>` for standalone home entities.
- `den.schema.<kind>` for entity schemas and new entity kinds.
- `den.aspects.*` for concrete and reusable behavior.
- `den.policies.*` for topology/effect functions.
- `den.quirks.*` for pipe data keys.
- `den.batteries.*` for built-in reusable behavior.
- `den.ful.<namespace>` / `den.namespace` for reusable aspect libraries.

`den.provides` and `den._` remain compatibility aliases for batteries, but new code uses `den.batteries`. `den.ctx`, `den.lib.parametric`, `perHost`/`perUser` helpers, and direct `den.lib.aspects.resolve` usage are legacy/internal patterns, not the day-to-day architecture API.

## Operating Rules

1. **Facts live in entities and schema.** A host declaration says where a machine lives, what it is, and what it exposes.
2. **Behavior lives in aspects.** NixOS, Darwin, Home Manager, flake-parts, Terranix, monitoring, and docs contributions belong in named aspects.
3. **Topology lives in policies.** If a relationship changes scope visibility or output instantiation, make it a policy.
4. **Operational lists live in quirks/pipes.** Workloads emit data; collectors assemble it; consumers render config.
5. **Reusable API lives in `lab`.** Raw Den mechanics are wrapped behind local `lab.roles.*`, `lab.features.*`, `lab.workloads.*`, `lab.policies.*`, and `lab.quirks.*` conventions.
6. **Concrete host aspects stay thin.** If `den.aspects.<host>` becomes a long NixOS module, the design has relapsed into host-first sprawl.

## Entity Graph

The default Den graph can resolve hosts, users, homes, and flake outputs directly. The homelab uses a richer graph when topology matters:

```text
flake
└── site
    └── environment
        └── host
            ├── user
            ├── workload
            └── microvm guest
```

Small installations may keep `site`, `environment`, and `workloads` as host schema fields. Larger installations promote them into first-class entity kinds by defining `den.schema.<kind>.isEntity = true`, adding a typed registry, and resolving them with `den.lib.policy.resolve.to "<kind>"`.

Custom topology can replace Den's default host/home walking policies, but it must do so deliberately. If a policy manually instantiates hosts from an environment or fleet scope, exclude the default system-output policies that would otherwise walk the same hosts twice.

## Host Inventory

Hosts are declared as facts:

```nix
den.hosts.x86_64-linux.nas = {
  site = "home";
  environment = "prod";
  role = "storage-node";
  addr = "10.0.0.10";
  domain = "home.arpa";
  storage.zfs = true;
  workloads = [ "samba" "restic" "prometheus-node" ];

  users.alice.primary = true;
  users.backup.service = true;
};
```

A host declaration answers:

- where the machine lives;
- what role it plays;
- which users exist there;
- which workloads belong there;
- which capabilities it advertises;
- which output class should instantiate it.

It does not contain large NixOS modules. Implementation belongs in aspects.

## Host and User Aspects

Concrete host aspects are composition points:

```nix
den.aspects.nas.includes = [
  lab.roles.storage-node
  lab.features.zfs
  lab.features.backups
  lab.features.monitoring-agent
  lab.workloads.samba
];
```

Concrete user aspects are also composition points:

```nix
den.aspects.alice.includes = [
  den.batteries.primary-user
  (den.batteries.user-shell "fish")
  lab.features.git
  lab.features.operator-shell
];
```

Den 0.17.0 supports flat-form class modules with Den context injection. Prefer this shape:

```nix
lab.features.hostname.nixos = { host, ... }: {
  networking.hostName = host.hostName;
};
```

The older two-stage style still works, but flat modules are clearer. Include `...` when a class module also needs Nix module-system arguments (`config`, `pkgs`, `lib`, etc.). If a class module requires a context arg that is absent in the current scope, Den skips it; this allows one aspect to contain host-only and user-only contributions safely.

## Local Aspect Library

The local namespace is `lab`. It is the day-to-day API for this repo:

```text
lab.roles.*       # server, workstation, storage-node, edge-router, media-server
lab.features.*    # ssh, tailscale, backups, monitoring-agent, reverse-proxy
lab.workloads.*   # forgejo, grafana, prometheus, immich, jellyfin, postgresql
lab.hardware.*    # zfs, nvidia, raspberry-pi, laptop-power
lab.platform.*    # nixos-baseline, darwin-baseline, microvm-guest, wsl
lab.infra.*       # hcloud-server, dns-zone, terraform-provider
lab.users.*       # alice, deploy, backup, service users
lab.policies.*    # topology and collector helpers
lab.quirks.*      # typed payload constructors/assertions
```

Reusable homelab building blocks live under `lab`; concrete `den.aspects.<host>` and `den.aspects.<user>` entries wire entity-specific composition. The namespace may be exported through `den.ful.lab` once it becomes reusable outside this repo, but initial migration keeps it in-repo.

## Schema Vocabulary

Schemas make infrastructure vocabulary typed and discoverable. Recurring fields belong in `den.schema.*`; one-off exploratory values may be freeform only while the model is being shaped.

Host metadata includes:

- `site`
- `environment`
- `role`
- `addr`
- `domain`
- `fqdn`
- `vlan`
- `tags`
- `workloads`
- `backup.enable`
- `monitoring.enable`
- `hardware.gpu`
- `storage.zfs`
- `infra.provider`
- `infra.region`

User metadata includes:

- `primary`
- `service`
- `sshOnly`
- `groups`
- `shell`
- `git.email`
- `classes`

Custom entity kinds use schema too. The homelab promotes a concept to an entity when it needs policy routing, scoped pipe collection, generated documentation, or output instantiation:

```nix
den.schema.environment = { lib, ... }: {
  isEntity = true;
  strict = true;
  options = {
    site = lib.mkOption { type = lib.types.str; };
    tier = lib.mkOption { type = lib.types.enum [ "prod" "staging" "dev" ]; };
  };
};
```

Schema is metadata. Aspects consume metadata to render class modules.

## Batteries

Den 0.17.0 moved built-ins to `den.batteries`. Important batteries for this homelab are:

- `define-user` — creates OS user declarations from user entities.
- `primary-user` — marks the primary user for a host/user scope.
- `user-shell` — assigns a user shell.
- `hostname` — derives hostnames from host entities.
- `os-class` / `os-user` — route generic OS/user content to platform-specific classes.
- `home-manager`, `hjem`, `maid` — enable user environment classes.
- `host-aspects` — lets user scopes opt into compatible class content from the host aspect tree.
- `forward` — builds custom forwarding classes.
- `import-tree` — imports aspect trees from directories.
- `unfree` / `insecure` — carry nixpkgs policy for user environment classes.
- `inputs'` / `self'` — expose flake-parts values in Den scopes.
- `wsl`, `tty-autologin`, `vm-autologin` — platform/runtime conveniences.

Default fleet wiring uses batteries sparingly:

```nix
den.default.includes = [
  den.batteries.hostname
  den.batteries.define-user
  lab.features.nix-baseline
  lab.features.ssh-baseline
];
```

Role-specific behavior never belongs in `den.default`.

## Workloads

A workload is one semantic service across every class and operational stream it touches:

```nix
lab.workloads.grafana = {
  includes = [ lab.features.reverse-proxy ];

  nixos = { host, ... }: {
    services.grafana.enable = true;
    services.grafana.settings.server.domain = "grafana.${host.domain}";
  };

  monitoring-targets = { host, ... }: {
    name = "grafana";
    address = host.addr;
    port = 3000;
  };

  reverse-proxy-vhosts = { host, ... }: {
    domain = "grafana.${host.domain}";
    upstream = "http://${host.addr}:3000";
  };
};
```

The workload does not edit global monitoring or proxy lists. It emits quirk data. Collector policies assemble data for consumers.

## Operational Data Flow

Quirks are declared centrally:

```nix
den.quirks.monitoring-targets.description =
  "Prometheus scrape targets emitted by hosts and workloads";

den.quirks.reverse-proxy-vhosts.description =
  "Virtual hosts emitted by workloads";

den.quirks.backup-jobs.description =
  "Backup jobs emitted by stateful services";
```

Collector policies define the visibility boundary:

```nix
den.policies.collect-monitoring-targets = { host, ... }: [
  (den.lib.policy.pipe.from "monitoring-targets" [
    (den.lib.policy.pipe.collect ({ host, ... }: true))
    den.lib.policy.pipe.withProvenance
  ])
];
```

Consumers receive assembled data via class module args:

```nix
lab.roles.monitoring-server.nixos =
  { monitoring-targets, lib, ... }:
  {
    services.prometheus.scrapeConfigs = map
      (target: {
        job_name = target.value.name;
        static_configs = [{
          targets = [ "${target.value.address}:${toString target.value.port}" ];
        }];
      })
      monitoring-targets;
  };
```

Den 0.17.0 pipe stages include `filter`, `transform`, `fold`, `append`, `for`, `collect`, `to`, `as`, `expose`, and `withProvenance`. `pipe.as` adapts one quirk stream into another, which is useful when workloads emit service-local data and an environment-level collector needs a normalized stream.

Pipe collection is scoped by the policy graph. Do not assume a global ordering or global visibility boundary. If the monitoring server should see only its environment, collect from the environment scope. If it should see the fleet, collect from the fleet scope.

Quirk payloads are still weakly typed upstream. The homelab layer therefore owns typed constructors/assertions in `lab.quirks.*` before relying on a quirk for production monitoring, proxying, DNS, backups, or firewall rendering.

## Users, Homes, and Operator Toolchains

Users are portable identities. Host declarations state user presence; user aspects describe behavior.

```nix
den.schema.user.classes = lib.mkDefault [ "homeManager" ];

den.aspects.alice.includes = [
  den.batteries.primary-user
  (den.batteries.user-shell "fish")
  lab.features.git
  lab.features.operator-tools
];
```

Standalone homes exist when the activation boundary is user-owned rather than host-owned:

```nix
den.homes.x86_64-linux."alice@workstation" = { };
```

Host-managed and standalone homes share the same user aspects where possible.

Operator packages that have no host dependency belong in Home Manager/home-class aspects, not host-wide `environment.systemPackages`. That does **not** automatically require a separate repository. The lifecycle split is modeled first as `lab.features.operator-tools` or `lab.users.<name>` home aspects; it graduates to a nested flake or separate repo only when it needs its own lockfile cadence, CI, cross-repo reuse, or non-host deployment surface.

Den 0.17.0's `host-aspects` battery matters here: a user can opt into compatible classes from the host aspect tree. Use it when host context should project home/user behavior, but avoid making host aspects the dumping ground for portable user tools.

## Flake-Parts and Non-OS Outputs

Den 0.17.0 treats flake outputs and flake-parts as first-class routing surfaces. Aspects can contribute not only OS modules but also `packages`, `checks`, `devShells`, `apps`, files, tests, or custom flake-parts module classes.

The homelab uses this for infrastructure support code:

```nix
lab.features.operator-tools = {
  homeManager = { pkgs, ... }: {
    home.packages = [ pkgs.nil pkgs.nixd pkgs.alejandra ];
  };

  checks = { pkgs, ... }: {
    operator-tools-smoke = pkgs.runCommand "operator-tools-smoke" { } ''
      touch $out
    '';
  };
};
```

This is the right first split for user packages nested under Home Manager: separate the class and aspect boundary before splitting the repo. A new flake boundary is justified when the toolchain becomes a product with independent consumers or update gates.

## MicroVMs

MicroVM guests are first-class hosts when Den owns their OS graph. They can be hidden from top-level outputs with `intoAttr = [ ]` when they exist only through a parent host.

```nix
den.hosts.x86_64-linux.server.microvm.guests = [
  den.hosts.x86_64-linux.home-assistant-vm
];

den.hosts.x86_64-linux.home-assistant-vm = {
  intoAttr = [ ];
  role = "microvm";
  users.alice = { };
};
```

Guest behavior remains ordinary aspect composition.

## Infra Outputs

Cloud/provider resources use custom classes or library-only Den patterns. A host can contribute NixOS configuration and Terranix resources from the same aspect:

```nix
lab.roles.vps = {
  includes = [ lab.infra.hcloud-server lab.features.ssh ];

  nixos.services.openssh.enable = true;

  terranix = { host, ... }: {
    resource.hcloud_server.${host.name} = {
      name = host.hostName;
      server_type = host.infra.server-type;
      location = host.infra.region;
    };
  };
};
```

The host remains one semantic entity even when multiple outputs are generated from it.

## Defaults and Release State

`den.default` contains only true fleet-wide baseline behavior:

```nix
den.default = {
  nixos.system.stateVersion = "26.05";
  homeManager.home.stateVersion = "26.05";

  includes = [
    den.batteries.hostname
    den.batteries.define-user
    lab.features.nix-baseline
    lab.features.ssh-baseline
  ];
};
```

`system.stateVersion` and `home.stateVersion` are compatibility pins, not package channels. They move only as a deliberate migration step. The architecture targets the current host release line, but implementation must preserve NixOS/Home Manager state-version rules.

## Diagrams and Documentation Outputs

Architecture diagrams are generated from Den's resolved graph. They are documentation artifacts backed by the same model that builds systems.

The diagram set includes:

```text
docs/architecture/
  fleet.md
  hosts/nas.md
  hosts/router.md
  users/alice.md
  classes/nixos.md
  classes/homeManager.md
  graphs/fleet-c4.svg
  graphs/provider-matrix.svg
  graphs/pipes.md
  fleet-ir.json
```

The diagrams answer:

- which aspects configure a host;
- which classes a concern contributes to;
- which workloads emit which operational data;
- which policies create scope boundaries;
- which cross-host pipes feed consumers;
- which outputs are generated for OS, home, flake-parts, and infra classes.

Generated diagrams are evidence. Hand-maintained diagrams are sketches.

## Review Standard

A change is Den-shaped when:

- entities are facts;
- aspects are reusable behavior;
- policies express topology;
- quirks carry aggregated data;
- schemas define recurring vocabulary;
- concrete host aspects remain thin;
- portable user toolchains live in home/user aspects, not host packages;
- custom classes are registered and routed explicitly;
- docs describe the graph as it exists.

A change is rejected when it uses Den syntax to preserve host-first copy/paste.

## Migration Starting Point for `nixos-hermes`

For the current repo, the first useful Den migration is not a separate flake. It is an in-repo class/aspect split:

1. Define a local `lab` namespace.
2. Move portable Home Manager packages from host-oriented modules into `lab.features.operator-tools`.
3. Attach `lab.features.operator-tools` to the intended user/home entities (`admin`, `hermes`, or both), explicitly preserving service-persona access where needed.
4. Keep host services such as Hermes Agent, Netdata, SOPS, ZFS, Docker, libvirt, and systemd wiring in host/platform/workload aspects because they have host runtime dependencies.
5. Add typed quirk constructors before using cross-service operational streams.
6. Add generated diagram/check outputs once the Den graph exists.

A nested or separate flake becomes appropriate only after the home/operator toolchain has an independent lifecycle: separate lock cadence, cross-machine consumers, independent CI, or reuse outside this host repo. Splitting earlier would be repo sprawl with nicer branding.

## Den 0.17.0 Pitfalls to Avoid

- Do not write new docs using `den.provides`; use `den.batteries`.
- Do not use `den.ctx` as the core model; it is compatibility glue.
- Do not wrap every context function in `den.lib.parametric`; bare functions dispatch automatically.
- Do not compare entities with `==`; use stable identity such as `id_hash` where filtering requires identity.
- Do not rely on quirk payload typing from upstream Den; enforce payload shape in `lab.quirks.*`.
- Do not activate custom topology policies without checking whether default policies need exclusion.
- Do not route user packages through host-wide packages when they are home-class concerns.
- Do not pretend non-NixOS machines are NixOS outputs. Keep the entity; change the class.
- Do not treat generated diagrams as decoration. If the graph cannot generate useful docs, the model is probably still too implicit.
