{ lib, ... }:

let
  pathList = lib.types.listOf lib.types.str;
in
{
  den.schema.host.imports = [
    {
      options = {
        moduleImports = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Flattened Den-owned host module graph consumed by flake.nix.";
        };

        hardwareModules = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Host hardware, boot, kernel, GPU, and physical-machine modules.";
        };

        storageModules = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Host storage layout modules such as Disko/ZFS layout.";
        };

        secretModules = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Host secret binding modules such as sops-nix bindings.";
        };

        platformModules = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Host platform/substrate modules such as provisioning and virtualisation.";
        };

        serviceModules = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Host runtime service modules selected by the Den host graph.";
        };

        sharedModules = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Shared NixOS modules selected by the Den host graph.";
        };

        nixpkgsHostPlatform = lib.mkOption {
          type = lib.types.str;
          description = "Configured nixpkgs host platform for this host.";
        };

        hostId = lib.mkOption {
          type = lib.types.str;
          description = "Configured networking.hostId for this host.";
        };

        stateVersion = lib.mkOption {
          type = lib.types.str;
          description = "Configured NixOS stateVersion for this host.";
        };

        timeZone = lib.mkOption {
          type = lib.types.str;
          description = "Configured system time zone.";
        };

        defaultLocale = lib.mkOption {
          type = lib.types.str;
          description = "Configured default locale.";
        };

        consoleKeyMap = lib.mkOption {
          type = lib.types.str;
          description = "Configured console keymap.";
        };

        systemPackages = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Host baseline package attribute names.";
        };

        trustedUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Nix trusted-users declared for this host.";
        };

        storage.zfs = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether current host configuration enables ZFS storage semantics.";
        };

        storage.diskoConfigPath = lib.mkOption {
          type = lib.types.str;
          description = "Repository-relative Disko configuration path for install-time tooling.";
        };
      };
    }
  ];

  den.schema.user.imports = [
    {
      options = {
        normalUser = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Mirrors users.users.<name>.isNormalUser when present.";
        };

        hasHomeManagerConfig = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether the Den-rendered Home Manager graph declares a config for this user.";
        };

        home = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Mirrors users.users.<name>.home when present.";
        };

        createHome = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = "Mirrors users.users.<name>.createHome when present.";
        };

        homeMode = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Mirrors users.users.<name>.homeMode when present.";
        };

        extraGroups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Mirrors users.users.<name>.extraGroups.";
        };

        sshAuthorizedKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Mirrors users.users.<name>.openssh.authorizedKeys.keys.";
        };

      };
    }
  ];
}
