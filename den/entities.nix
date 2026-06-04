{
  den.hosts.x86_64-linux.nixos-hermes = {
    moduleImports = [
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

    serviceModules = [
      "hosts/hermes/llama-server.nix"
      "hosts/hermes/hindsight-embed.nix"
      "hosts/hermes/hindsight-memory.nix"
      "hosts/hermes/agentmemory.nix"
      "hosts/hermes/netdata.nix"
      "hosts/hermes/omp-auth-gateway.nix"
      "modules/hermes-agent.nix"
      "modules/hermes-plugins.nix"
    ];

    sharedModules = [
      "modules/system.nix"
      "modules/packages.nix"
      "modules/home-manager.nix"
      "modules/users.nix"
    ];

    nixpkgsHostPlatform = "x86_64-linux";
    stateVersion = "25.05";
    trustedUsers = [ "admin" ];
    storage.zfs = true;

    users.admin = {
      normalUser = true;
      hasHomeManagerConfig = true;
      home = "/home/admin";
      createHome = true;
      homeMode = "700";
      extraGroups = [
        "wheel"
        "networkmanager"
        "hermes"
      ];
      sshAuthorizedKeysConfigured = true;
      classes = [ "homeManager" ];
    };

    users.hermes = {
      normalUser = false;
      hasHomeManagerConfig = true;
      sshAuthorizedKeysConfigured = true;
      classes = [ "homeManager" ];
    };
  };

  den.aspects.nixos-hermes.includes = [ ];
  den.aspects.admin.includes = [ ];
  den.aspects.hermes.includes = [ ];
}
