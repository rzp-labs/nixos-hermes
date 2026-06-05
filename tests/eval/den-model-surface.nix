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
    "den/hosts/nixos-hermes/storage/disk-config.nix"
    "den/hosts/nixos-hermes/services/agentmemory.nix"
    "den/hosts/nixos-hermes/services/netdata.nix"
    "den/hosts/nixos-hermes/services/hermes-agent/default.nix"
    "den/hosts/nixos-hermes/services/hermes-agent/plugins.nix"
  ];
  expectedHardwareModules = [ ];
  expectedStorageModules = [
    "den/hosts/nixos-hermes/storage/disk-config.nix"
  ];
  expectedSecretModules = [ ];
  expectedPlatformModules = [ ];
  expectedServiceModules = [
    "den/hosts/nixos-hermes/services/agentmemory.nix"
    "den/hosts/nixos-hermes/services/netdata.nix"
    "den/hosts/nixos-hermes/services/hermes-agent/default.nix"
    "den/hosts/nixos-hermes/services/hermes-agent/plugins.nix"
  ];
  expectedSharedModules = [ ];
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
  test '${boolString host.userManagement.mutableUsers}' = 'false'
  test '${builtins.concatStringsSep "," host.userManagement.tmpfilesRules}' = 'd /home/admin/workspace 0755 admin users - -'
  test '${boolString host.homeManager.useGlobalPkgs}' = 'true'
  test '${boolString host.homeManager.useUserPackages}' = 'true'
  test '${builtins.concatStringsSep "," host.systemPackages}' = 'curl,wget,git,man,htop,iotop,tree,jq,python3,ripgrep,unzip,gh,bun,fh,repowise,repowise-nix,llm-agents.cli-proxy-api,llm-agents.but,uv'
  test '${boolString host.storage.zfs}' = 'true'
  test '${boolString host.hardware.importNotDetected}' = 'true'
  test '${builtins.concatStringsSep "," host.hardware.initrdAvailableKernelModules}' = 'xhci_pci,ahci,nvme,thunderbolt,usbhid,usb_storage,sd_mod,sr_mod'
  test -z '${builtins.concatStringsSep "," host.hardware.initrdKernelModules}'
  test '${builtins.concatStringsSep "," host.hardware.kernelModules}' = 'kvm-intel'
  test '${builtins.concatStringsSep "," host.hardware.kernelParams}' = 'zfs.zfs_arc_max=17179869184,nvme_core.default_ps_max_latency_us=0'
  test '${toString host.hardware.kernelSysctl."vm.swappiness"}' = '0'
  test '${boolString host.hardware.zfsForceImportRoot}' = 'false'
  test -z '${builtins.concatStringsSep "," host.hardware.extraModulePackages}'
  test '${boolString host.hardware.boot.efiCanTouchVariables}' = 'true'
  test '${boolString host.hardware.boot.systemdBootEnable}' = 'true'
  test '${boolString host.hardware.boot.fallbackSync.enable}' = 'true'
  test '${host.hardware.boot.fallbackSync.source}' = '/boot/'
  test '${host.hardware.boot.fallbackSync.target}' = '/boot-fallback/'
  test '${boolString host.hardware.enableRedistributableFirmware}' = 'true'
  test '${boolString host.hardware.cpu.intel.updateMicrocodeFromRedistributableFirmware}' = 'true'
  test '${boolString host.hardware.graphics.enable}' = 'true'
  test '${builtins.concatStringsSep "," host.hardware.graphics.extraPackages}' = 'intel-media-driver,vpl-gpu-rt,intel-compute-runtime'
  test '${toString (builtins.length host.hardware.swapDevices)}' = '0'
  test '${host.hardware.cpuFreqGovernor}' = 'schedutil'
  test '${boolString host.hardware.zfsMaintenance.autoScrub}' = 'true'
  test '${boolString host.hardware.zfsMaintenance.trim}' = 'true'
  test '${host.storage.diskoConfigPath}' = 'den/hosts/nixos-hermes/storage/disk-config.nix'
  test '${boolString host.platform.virtualisation.docker.enable}' = 'true'
  test '${host.platform.virtualisation.docker.storageDriver}' = 'zfs'
  test '${host.platform.virtualisation.docker.autoPruneDates}' = 'weekly'
  test '${boolString host.platform.virtualisation.libvirt.enable}' = 'true'
  test '${builtins.concatStringsSep "," host.platform.virtualisation.rootEquivalentGroups}' = 'docker,libvirtd'
  test '${builtins.concatStringsSep "," host.platform.virtualisation.packages}' = 'docker-compose,lazydocker,virtiofsd'
  test '${boolString host.platform.provisioning.soul.enable}' = 'true'
  test '${builtins.concatStringsSep "," host.platform.provisioning.soul.after}' = 'hermes-agent-setup,setupSecrets'
  test '${host.platform.provisioning.soul.secretName}' = 'hermes-soul-md'
  test '${host.platform.provisioning.soul.relativePath}' = '.hermes/SOUL.md'
  test '${boolString host.platform.provisioning.githubAuth.enable}' = 'true'
  test '${builtins.concatStringsSep "," host.platform.provisioning.githubAuth.after}' = 'hermes-agent-setup,setupSecrets,users'
  test '${host.platform.provisioning.githubAuth.secretName}' = 'hermes-env'
  test '${host.platform.provisioning.githubAuth.tokenVariable}' = 'GITHUB_TOKEN'
  test '${host.platform.provisioning.githubAuth.username}' = 'yui-hermes'
  test '${boolString host.services.hindsightMemory.enable}' = 'false'
  test '${builtins.concatStringsSep "," host.services.hindsightMemory.activationAfter}' = 'hermes-agent-setup'
  test '${host.services.hindsightMemory.providerConfig.mode}' = 'local_external'
  test '${host.services.hindsightMemory.providerConfig.api_url}' = 'http://127.0.0.1:8888'
  test '${host.services.hindsightMemory.providerConfig.bank_id}' = 'hermes'
  test '${host.services.hindsightMemory.providerConfig.bank_id_template}' = 'hermes-{profile}'
  test '${host.services.hindsightMemory.providerConfig.budget}' = 'mid'
  test '${host.services.hindsightMemory.llm.provider}' = 'openai'
  test '${host.services.hindsightMemory.llm.baseUrl}' = 'http://10.0.0.102:8317/v1'
  test '${host.services.hindsightMemory.llm.model}' = 'gpt-5.4-mini'
  test '${toString host.services.hindsightMemory.llm.timeout}' = '120'
  test '${toString host.services.ompAuthGateway.brokerPort}' = '9000'
  test '${toString host.services.ompAuthGateway.gatewayPort}' = '4000'
  test '${host.services.ompAuthGateway.bindHost}' = '127.0.0.1'
  test '${host.services.ompAuthGateway.adminHome}' = '/home/admin'
  test '${host.services.ompAuthGateway.primaryModel}' = 'gpt-5.5'
  test '${host.services.ompAuthGateway.fallbackModel}' = 'gemini-3-flash-agent'
  test '${host.services.ompAuthGateway.delegationModel}' = 'gemini-3-flash-agent'
  test '${host.services.ompAuthGateway.localApiKey}' = 'local-auth-gateway'
  test '${boolString host.services.hindsightMemory.llama.enable}' = 'false'
  test '${host.services.hindsightMemory.llama.modelPath}' = '/var/lib/hermes/models/google_gemma-4-E2B-it-Q6_K_L.gguf'
  test '${host.services.hindsightMemory.llama.host}' = '127.0.0.1'
  test '${toString host.services.hindsightMemory.llama.port}' = '8080'
  test '${toString host.services.hindsightMemory.llama.contextSize}' = '8192'
  test '${toString host.services.hindsightMemory.llama.threads}' = '10'
  test '${boolString host.services.hindsightMemory.llama.enableEmbeddings}' = 'true'
  test '${host.services.hindsightMemory.llama.pooling}' = 'mean'
  test '${nullableString host.services.hindsightMemory.llama.chatTemplate}' = 'null'
  test '${host.secrets.defaultSopsFile}' = 'den/hosts/nixos-hermes/secrets/payload/hermes-secrets.yaml'
  test '${host.secrets.ageKeyFile}' = '/etc/secrets/age.key'
  test -z '${builtins.concatStringsSep "," host.secrets.ageSshKeyPaths}'
  test '${builtins.concatStringsSep "," (builtins.attrNames host.secrets.bindings)}' = 'cliproxyapi-key,hermes-env,hermes-soul-md,netdata-claim-conf,omp-auth-broker-token,ssh_host_ed25519_key'
  test '${host.secrets.bindings.ssh_host_ed25519_key.path}' = '/etc/ssh/ssh_host_ed25519_key'
  test '${host.secrets.bindings.ssh_host_ed25519_key.format}' = 'binary'
  test '${host.secrets.bindings."hermes-env".owner}' = 'hermes'
  test '${host.secrets.bindings.netdata-claim-conf.group}' = 'netdata'
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
