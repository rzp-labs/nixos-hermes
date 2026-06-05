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
          description = "Host module imports mirrored from the current NixOS entrypoint.";
        };

        serviceModules = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Host-owned service module files currently imported by the host entrypoint.";
        };

        sharedModules = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Shared module files currently imported by the host entrypoint.";
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
          description = "Whether modules/home-manager.nix declares a Home Manager config for this user.";
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
