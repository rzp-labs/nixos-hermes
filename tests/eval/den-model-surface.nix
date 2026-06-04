# tests/eval/den-model-surface.nix
# Eval check: Den model surface mirrors current host/user facts without driving deployment.
{
  pkgs,
  denModel,
  ...
}:
let
  host = denModel.den.hosts.x86_64-linux.nixos-hermes;
  admin = host.users.admin;
  hermes = host.users.hermes;
  lab = denModel.den.ful.lab;

  requiredLabCategories = [
    "roles"
    "features"
    "workloads"
    "hardware"
    "platform"
    "users"
    "quirks"
  ];

  boolString = value: if value then "true" else "false";
  nullableBoolString = value: if value == null then "null" else boolString value;
  nullableString = value: if value == null then "null" else value;
  missingLabCategories = builtins.filter (name: !(builtins.hasAttr name lab)) requiredLabCategories;

  expectedModuleImports = [
    "hosts/hermes/hardware.nix"
    "hosts/hermes/disk-config.nix"
    "hosts/hermes/sops.nix"
    "hosts/hermes/provision.nix"
    "hosts/hermes/virtualisation.nix"
    "hosts/hermes/llama-server.nix"
    "hosts/hermes/hindsight-embed.nix"
    "hosts/hermes/hindsight-memory.nix"
    "hosts/hermes/agentmemory.nix"
    "hosts/hermes/netdata.nix"
    "hosts/hermes/omp-auth-gateway.nix"
    "modules/system.nix"
    "modules/packages.nix"
    "modules/home-manager.nix"
    "modules/hermes-agent.nix"
    "modules/hermes-plugins.nix"
    "modules/users.nix"
  ];
  expectedServiceModules = [
    "hosts/hermes/llama-server.nix"
    "hosts/hermes/hindsight-embed.nix"
    "hosts/hermes/hindsight-memory.nix"
    "hosts/hermes/agentmemory.nix"
    "hosts/hermes/netdata.nix"
    "hosts/hermes/omp-auth-gateway.nix"
    "modules/hermes-agent.nix"
    "modules/hermes-plugins.nix"
  ];
  expectedSharedModules = [
    "modules/system.nix"
    "modules/packages.nix"
    "modules/home-manager.nix"
    "modules/users.nix"
  ];
in
pkgs.runCommand "den-model-surface" { } ''
  set -eu
  test '${host.name}' = 'nixos-hermes'
  test '${builtins.concatStringsSep "," host.moduleImports}' = '${builtins.concatStringsSep "," expectedModuleImports}'
  test '${builtins.concatStringsSep "," host.serviceModules}' = '${builtins.concatStringsSep "," expectedServiceModules}'
  test '${builtins.concatStringsSep "," host.sharedModules}' = '${builtins.concatStringsSep "," expectedSharedModules}'
  test '${host.nixpkgsHostPlatform}' = 'x86_64-linux'
  test '${host.stateVersion}' = '25.05'
  test '${builtins.concatStringsSep "," host.trustedUsers}' = 'admin'
  test '${boolString host.storage.zfs}' = 'true'
  test '${admin.name}' = 'admin'
  test '${boolString admin.normalUser}' = 'true'
  test '${boolString admin.hasHomeManagerConfig}' = 'true'
  test '${nullableString admin.home}' = '/home/admin'
  test '${nullableBoolString admin.createHome}' = 'true'
  test '${nullableString admin.homeMode}' = '700'
  test '${builtins.concatStringsSep "," admin.extraGroups}' = 'wheel,networkmanager,hermes'
  test '${boolString admin.sshAuthorizedKeysConfigured}' = 'true'
  test '${builtins.concatStringsSep "," admin.classes}' = 'homeManager'
  test '${hermes.name}' = 'hermes'
  test '${boolString hermes.normalUser}' = 'false'
  test '${boolString hermes.hasHomeManagerConfig}' = 'true'
  test '${nullableString hermes.home}' = 'null'
  test '${nullableBoolString hermes.createHome}' = 'null'
  test '${nullableString hermes.homeMode}' = 'null'
  test -z '${builtins.concatStringsSep "," hermes.extraGroups}'
  test '${boolString hermes.sshAuthorizedKeysConfigured}' = 'true'
  test '${builtins.concatStringsSep "," hermes.classes}' = 'homeManager'
  test -z '${builtins.concatStringsSep "," missingLabCategories}'
  touch $out
''
