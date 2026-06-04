# tests/eval/default.nix — pure-evaluation assertion checks
#
# These derivations introspect the built host configuration
# (`self.nixosConfigurations.nixos-hermes`) and assert on rendered values:
# service unit config, package versions, wrapper script contents, plugin
# wiring, etc. They are evaluation/build checks, not VM tests — they sit
# alongside the VM suite in ./.. and surface through the flake `checks`
# output for x86_64-linux only.
#
# Run an individual check with:
#   nix build .#checks.x86_64-linux.<name>
#
# `hostSystem` is the evaluated NixOS system attrset; each check receives
# the host `config` and `pkgs` it needs.
{
  pkgs,
  hostSystem,
  denModel,
}:
let
  hostConfig = hostSystem.config;
  hostPkgs = hostSystem.pkgs;
  call = f: import f { inherit pkgs hostConfig hostPkgs; };
  callDen =
    f:
    import f {
      inherit
        pkgs
        hostConfig
        hostPkgs
        denModel
        ;
    };
in
{
  hermes-runtime-packaging = call ./hermes-runtime-packaging.nix;
  repowise-nix-tooling = call ./repowise-nix-tooling.nix;
  agentmemory-service-config = call ./agentmemory-service-config.nix;
  netdata-service-config = call ./netdata-service-config.nix;
  hindsight-service-config = call ./hindsight-service-config.nix;
  den-model-surface = callDen ./den-model-surface.nix;
}
