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

        nixpkgs.allowedUnfree = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Unfree package names explicitly allowed for this host.";
        };

        trustedUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Nix trusted-users declared for this host.";
        };

        userManagement.mutableUsers = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether local user state may diverge from declarative user definitions.";
        };

        userManagement.tmpfilesRules = lib.mkOption {
          type = pathList;
          default = [ ];
          description = "Host tmpfiles rules associated with declarative user/home state.";
        };

        homeManager.useGlobalPkgs = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether Home Manager NixOS integration uses the system pkgs instance.";
        };

        homeManager.useUserPackages = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether Home Manager installs packages through user profiles.";
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

        services.hindsightMemory.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether the retired Hindsight memory substrate is selected for Hermes.";
        };

        services.hindsightMemory.providerConfig = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Provider configuration rendered to $HERMES_HOME/hindsight/config.json when Hindsight is enabled.";
        };

        services.hindsightMemory.activationAfter = lib.mkOption {
          type = pathList;
          default = [ "hermes-agent-setup" ];
          description = "Activation script dependencies for Hindsight provider config refresh.";
        };

        services.hindsightMemory.llm = lib.mkOption {
          type = lib.types.submodule {
            options = {
              provider = lib.mkOption {
                type = lib.types.str;
                default = "openai";
                description = "Hindsight LLM provider name. Use openai for OpenAI-compatible proxies.";
              };
              baseUrl = lib.mkOption {
                type = lib.types.str;
                default = "http://10.0.0.102:8317/v1";
                description = "OpenAI-compatible base URL used for Hindsight retain/reflect LLM calls.";
              };
              model = lib.mkOption {
                type = lib.types.str;
                default = "gpt-5.4-mini";
                description = "Model used for Hindsight retain/reflect LLM calls.";
              };
              timeout = lib.mkOption {
                type = lib.types.ints.positive;
                default = 120;
                description = "Timeout in seconds for Hindsight LLM calls through the external proxy.";
              };
            };
          };
          default = { };
          description = "Hindsight retain/reflect LLM route facts for the retired memory substrate.";
        };

        services.ompAuthGateway = lib.mkOption {
          type = lib.types.submodule {
            options = {
              brokerPort = lib.mkOption {
                type = lib.types.port;
                default = 9000;
                description = "Loopback port for the OMP OAuth broker.";
              };
              gatewayPort = lib.mkOption {
                type = lib.types.port;
                default = 4000;
                description = "Loopback port for the OMP OpenAI-compatible auth gateway.";
              };
              bindHost = lib.mkOption {
                type = lib.types.str;
                default = "127.0.0.1";
                description = "Loopback bind address for the OMP broker and gateway.";
              };
              adminHome = lib.mkOption {
                type = lib.types.str;
                default = "/home/admin";
                description = "Home directory that owns the OMP OAuth/auth state.";
              };
              primaryModel = lib.mkOption {
                type = lib.types.str;
                default = "gpt-5.5";
                description = "Primary Hermes model routed through the OMP auth gateway.";
              };
              fallbackModel = lib.mkOption {
                type = lib.types.str;
                default = "gemini-3-flash-agent";
                description = "Fallback Hermes model routed through a distinct upstream lane.";
              };
              delegationModel = lib.mkOption {
                type = lib.types.str;
                default = "gemini-3-flash-agent";
                description = "Delegated worker model routed through the OMP auth gateway.";
              };
              localApiKey = lib.mkOption {
                type = lib.types.str;
                default = "local-auth-gateway";
                description = "Non-secret local API key marker for loopback OpenAI-compatible clients.";
              };
            };
          };
          default = { };
          description = "OMP OAuth broker/auth-gateway facts for Hermes inference routing.";
        };

        services.hindsightMemory.llama = lib.mkOption {
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether the local llama.cpp inference server for Hindsight memory is enabled.";
              };
              modelPath = lib.mkOption {
                type = lib.types.str;
                default = "/var/lib/hermes/models/google_gemma-4-E2B-it-Q6_K_L.gguf";
                description = "Absolute path to the GGUF model served by llama.cpp.";
              };
              host = lib.mkOption {
                type = lib.types.str;
                default = "127.0.0.1";
                description = "Address for llama.cpp's OpenAI-compatible HTTP server.";
              };
              port = lib.mkOption {
                type = lib.types.port;
                default = 8080;
                description = "TCP port for llama.cpp's OpenAI-compatible HTTP server.";
              };
              contextSize = lib.mkOption {
                type = lib.types.ints.positive;
                default = 8192;
                description = "Context size passed to llama.cpp.";
              };
              threads = lib.mkOption {
                type = lib.types.ints.positive;
                default = 10;
                description = "CPU threads passed to llama.cpp.";
              };
              enableEmbeddings = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether to enable llama.cpp's OpenAI-compatible /v1/embeddings endpoint.";
              };
              pooling = lib.mkOption {
                type = lib.types.nullOr (
                  lib.types.enum [
                    "mean"
                    "cls"
                    "last"
                    "rank"
                  ]
                );
                default = "mean";
                description = "Pooling mode used by llama.cpp when embeddings are enabled.";
              };
              chatTemplate = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Chat template passed to llama.cpp; set to null to let llama.cpp infer it.";
              };
            };
          };
          default = { };
          description = "Local llama.cpp inference server facts for the retired Hindsight memory substrate.";
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
