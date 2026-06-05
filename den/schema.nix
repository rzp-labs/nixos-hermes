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

        hardware.importNotDetected = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to import NixOS' installer scan/not-detected hardware module.";
        };

        hardware.initrdAvailableKernelModules = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Initrd kernel modules detected for early boot.";
        };

        hardware.initrdKernelModules = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Initrd kernel modules forced for this host.";
        };

        hardware.kernelModules = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Runtime kernel modules forced for this host.";
        };

        hardware.kernelParams = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Kernel parameters for this host.";
        };

        hardware.kernelSysctl = lib.mkOption {
          type = lib.types.attrsOf lib.types.int;
          default = { };
          description = "Kernel sysctl values for this host.";
        };

        hardware.zfsForceImportRoot = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether ZFS root pools should be force-imported at boot.";
        };

        hardware.extraModulePackages = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Kernel module package attribute names for this host.";
        };

        hardware.boot.efiCanTouchVariables = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether systemd-boot may touch EFI variables.";
        };

        hardware.boot.systemdBootEnable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether systemd-boot is enabled.";
        };

        hardware.boot.fallbackSync = lib.mkOption {
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether to sync the primary ESP to a fallback ESP after systemd-boot install.";
              };
              source = lib.mkOption {
                type = lib.types.str;
                default = "/boot/";
                description = "Fallback sync source path.";
              };
              target = lib.mkOption {
                type = lib.types.str;
                default = "/boot-fallback/";
                description = "Fallback sync target path.";
              };
            };
          };
          default = { };
          description = "Fallback ESP synchronization settings.";
        };

        hardware.enableRedistributableFirmware = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether redistributable firmware is enabled.";
        };

        hardware.cpu.intel.updateMicrocodeFromRedistributableFirmware = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether Intel microcode follows the redistributable firmware setting.";
        };

        hardware.graphics.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether NixOS graphics support is enabled.";
        };

        hardware.graphics.extraPackages = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Graphics package attribute names for this host.";
        };

        hardware.swapDevices = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ ];
          description = "Swap device declarations for this host.";
        };

        hardware.cpuFreqGovernor = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "CPU frequency governor for this host.";
        };

        hardware.zfsMaintenance.autoScrub = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether ZFS auto-scrub is enabled.";
        };

        hardware.zfsMaintenance.trim = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether ZFS trim is enabled.";
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

        platform.provisioning.soul = lib.mkOption {
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether to seed Hermes SOUL.md from a SOPS secret on first activation.";
              };
              after = lib.mkOption {
                type = pathList;
                default = [ ];
                description = "Activation script dependencies for SOUL.md seeding.";
              };
              secretName = lib.mkOption {
                type = lib.types.str;
                default = "hermes-soul-md";
                description = "sops-nix secret name containing the SOUL.md source.";
              };
              relativePath = lib.mkOption {
                type = lib.types.str;
                default = ".hermes/SOUL.md";
                description = "Path under the Hermes state directory to seed.";
              };
              directoryMode = lib.mkOption {
                type = lib.types.str;
                default = "0750";
                description = "Mode for the parent Hermes state subdirectory.";
              };
              fileMode = lib.mkOption {
                type = lib.types.str;
                default = "0640";
                description = "Mode for the seeded SOUL.md file.";
              };
            };
          };
          default = { };
          description = "Hermes SOUL.md one-shot provisioning facts.";
        };

        platform.provisioning.githubAuth = lib.mkOption {
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether to refresh Hermes GitHub credentials from the Hermes env secret on every activation.";
              };
              after = lib.mkOption {
                type = pathList;
                default = [ ];
                description = "Activation script dependencies for GitHub credential refresh.";
              };
              secretName = lib.mkOption {
                type = lib.types.str;
                default = "hermes-env";
                description = "sops-nix env secret containing the GitHub token variable.";
              };
              tokenVariable = lib.mkOption {
                type = lib.types.str;
                default = "GITHUB_TOKEN";
                description = "Environment variable name to read from the env secret.";
              };
              username = lib.mkOption {
                type = lib.types.str;
                description = "GitHub username written to git and gh credential files.";
              };
              gitCredentialsRelativePath = lib.mkOption {
                type = lib.types.str;
                default = ".git-credentials";
                description = "Credential helper file path under the Hermes state directory.";
              };
              ghConfigRelativeDir = lib.mkOption {
                type = lib.types.str;
                default = ".config/gh";
                description = "GitHub CLI config directory under the Hermes state directory.";
              };
            };
          };
          default = { };
          description = "Hermes GitHub credential refresh provisioning facts.";
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
