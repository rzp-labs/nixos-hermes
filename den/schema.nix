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

        platform.virtualisation.docker.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether the host enables the Docker workload substrate.";
        };

        platform.virtualisation.docker.storageDriver = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Docker storage driver selected for this host.";
        };

        platform.virtualisation.docker.autoPruneDates = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Docker auto-prune schedule for this host.";
        };

        platform.virtualisation.libvirt.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether the host enables the libvirt/QEMU substrate.";
        };

        platform.virtualisation.rootEquivalentGroups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Root-equivalent groups granted to trusted host users for virtualisation substrate access.";
        };

        platform.virtualisation.packages = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Host package names required by the virtualisation substrate.";
        };

        secrets.defaultSopsFile = lib.mkOption {
          type = lib.types.str;
          description = "Repository-relative default SOPS file for this host.";
        };

        secrets.ageKeyFile = lib.mkOption {
          type = lib.types.str;
          description = "Host-local age identity file consumed by sops-nix.";
        };

        secrets.ageSshKeyPaths = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "SSH key paths allowed as age identities for sops-nix.";
        };

        secrets.bindings = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                sopsFile = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Repository-relative SOPS file override for this secret.";
                };
                format = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "sops-nix secret format override.";
                };
                owner = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Runtime owner for the decrypted secret.";
                };
                group = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Runtime group for the decrypted secret.";
                };
                mode = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Runtime mode for the decrypted secret.";
                };
                path = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Runtime destination path for the decrypted secret.";
                };
              };
            }
          );
          default = { };
          description = "sops-nix secret binding metadata rendered for this host.";
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
