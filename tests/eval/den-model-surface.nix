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
    "den/hosts/nixos-hermes/hardware/default.nix"
    "den/hosts/nixos-hermes/storage/disk-config.nix"
    "den/hosts/nixos-hermes/secrets/sops.nix"
    "den/hosts/nixos-hermes/platform/provision.nix"
    "den/hosts/nixos-hermes/platform/virtualisation.nix"
    "den/hosts/nixos-hermes/services/llama-server.nix"
    "den/hosts/nixos-hermes/services/hindsight-embed.nix"
    "den/hosts/nixos-hermes/services/hindsight-memory.nix"
    "den/hosts/nixos-hermes/services/agentmemory.nix"
    "den/hosts/nixos-hermes/services/netdata.nix"
    "den/hosts/nixos-hermes/services/omp-auth-gateway.nix"
    "den/hosts/nixos-hermes/services/hermes-agent/default.nix"
    "den/hosts/nixos-hermes/services/hermes-agent/plugins.nix"
    "den/hosts/nixos-hermes/shared/system.nix"
    "den/hosts/nixos-hermes/shared/packages.nix"
    "den/hosts/nixos-hermes/shared/home-manager.nix"
    "den/hosts/nixos-hermes/shared/users.nix"
  ];
  expectedHardwareModules = [
    "den/hosts/nixos-hermes/hardware/default.nix"
  ];
  expectedStorageModules = [
    "den/hosts/nixos-hermes/storage/disk-config.nix"
  ];
  expectedSecretModules = [
    "den/hosts/nixos-hermes/secrets/sops.nix"
  ];
  expectedPlatformModules = [
    "den/hosts/nixos-hermes/platform/provision.nix"
    "den/hosts/nixos-hermes/platform/virtualisation.nix"
  ];
  expectedServiceModules = [
    "den/hosts/nixos-hermes/services/llama-server.nix"
    "den/hosts/nixos-hermes/services/hindsight-embed.nix"
    "den/hosts/nixos-hermes/services/hindsight-memory.nix"
    "den/hosts/nixos-hermes/services/agentmemory.nix"
    "den/hosts/nixos-hermes/services/netdata.nix"
    "den/hosts/nixos-hermes/services/omp-auth-gateway.nix"
    "den/hosts/nixos-hermes/services/hermes-agent/default.nix"
    "den/hosts/nixos-hermes/services/hermes-agent/plugins.nix"
  ];
  expectedSharedModules = [
    "den/hosts/nixos-hermes/shared/system.nix"
    "den/hosts/nixos-hermes/shared/packages.nix"
    "den/hosts/nixos-hermes/shared/home-manager.nix"
    "den/hosts/nixos-hermes/shared/users.nix"
  ];
  allHostModulesUnderDen = builtins.all (
    path: builtins.substring 0 23 path == "den/hosts/nixos-hermes/"
  ) host.moduleImports;
  legacyHostsRootExists = builtins.pathExists (./../.. + "/hosts");
  legacyModulesRootExists = builtins.pathExists (./../.. + "/modules");
in
pkgs.runCommand "den-model-surface" { } ''
  set -eu
  test '${host.name}' = 'nixos-hermes'
  test '${builtins.concatStringsSep "," host.moduleImports}' = '${builtins.concatStringsSep "," expectedModuleImports}'
  test '${builtins.concatStringsSep "," host.hardwareModules}' = '${builtins.concatStringsSep "," expectedHardwareModules}'
  test '${builtins.concatStringsSep "," host.storageModules}' = '${builtins.concatStringsSep "," expectedStorageModules}'
  test '${builtins.concatStringsSep "," host.secretModules}' = '${builtins.concatStringsSep "," expectedSecretModules}'
  test '${builtins.concatStringsSep "," host.platformModules}' = '${builtins.concatStringsSep "," expectedPlatformModules}'
  test '${builtins.concatStringsSep "," host.serviceModules}' = '${builtins.concatStringsSep "," expectedServiceModules}'
  test '${builtins.concatStringsSep "," host.sharedModules}' = '${builtins.concatStringsSep "," expectedSharedModules}'
  test '${boolString allHostModulesUnderDen}' = 'true'
  test '${boolString legacyHostsRootExists}' = 'false'
  test '${boolString legacyModulesRootExists}' = 'false'
  test '${host.nixpkgsHostPlatform}' = 'x86_64-linux'
  test '${host.hostId}' = '52dd4e5a'
  test '${host.stateVersion}' = '25.05'
  test '${host.timeZone}' = 'America/Phoenix'
  test '${host.defaultLocale}' = 'en_US.UTF-8'
  test '${host.consoleKeyMap}' = 'us'
  test '${builtins.concatStringsSep "," host.trustedUsers}' = 'admin'
  test '${builtins.concatStringsSep "," host.systemPackages}' = 'curl,wget,git,man,htop,iotop,tree,jq,python3,ripgrep,unzip,gh,bun,fh,repowise,repowise-nix,llm-agents.cli-proxy-api,llm-agents.but,uv'
  test '${boolString host.storage.zfs}' = 'true'
  test '${host.storage.diskoConfigPath}' = 'den/hosts/nixos-hermes/storage/disk-config.nix'
  test '${admin.name}' = 'admin'
  test '${boolString admin.normalUser}' = 'true'
  test '${boolString admin.hasHomeManagerConfig}' = 'true'
  test '${nullableString admin.home}' = '/home/admin'
  test '${nullableBoolString admin.createHome}' = 'true'
  test '${nullableString admin.homeMode}' = '700'
  test '${builtins.concatStringsSep "," admin.extraGroups}' = 'wheel,networkmanager,hermes'
  test '${builtins.concatStringsSep "," admin.sshAuthorizedKeys}' = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG3neF+6qsDFb1pwr06mdW0mqMcxquAGNsjbGiG/Rj23'
  test '${builtins.concatStringsSep "," admin.classes}' = 'homeManager'
  test '${hermes.name}' = 'hermes'
  test '${boolString hermes.normalUser}' = 'false'
  test '${boolString hermes.hasHomeManagerConfig}' = 'true'
  test '${nullableString hermes.home}' = 'null'
  test '${nullableBoolString hermes.createHome}' = 'null'
  test '${nullableString hermes.homeMode}' = 'null'
  test -z '${builtins.concatStringsSep "," hermes.extraGroups}'
  test '${toString (builtins.length hermes.sshAuthorizedKeys)}' = '4'
  test '${builtins.concatStringsSep "," hermes.classes}' = 'homeManager'
  test -z '${builtins.concatStringsSep "," missingLabCategories}'
  touch $out
''
