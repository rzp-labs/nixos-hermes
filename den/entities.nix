{ config, inputs, ... }:

let
  host = config.den.hosts.x86_64-linux.nixos-hermes;
  admin = host.users.admin;
  hermes = host.users.hermes;
  root = host.users.root;
  denPoc = host.users.den-poc;
in
{
  den.hosts.x86_64-linux.nixos-hermes =
    let
      hardwareModules = [ ];
      storageModules = [ ];
      secretModules = [ ];
      platformModules = [ ];
      serviceModules = [
      ];
      sharedModules = [ ];
    in
    {
      inherit
        hardwareModules
        storageModules
        secretModules
        platformModules
        serviceModules
        sharedModules
        ;
      moduleImports =
        hardwareModules
        ++ storageModules
        ++ secretModules
        ++ platformModules
        ++ serviceModules
        ++ sharedModules;

      nixpkgsHostPlatform = "x86_64-linux";
      hostId = "52dd4e5a";
      stateVersion = "25.05";
      trustedUsers = [ "admin" ];
      userManagement.mutableUsers = false;
      userManagement.tmpfilesRules = [
        "d /home/admin/workspace 0755 admin users - -"
      ];
      homeManager = {
        useGlobalPkgs = true;
        useUserPackages = true;
      };
      timeZone = "America/Phoenix";
      defaultLocale = "en_US.UTF-8";
      consoleKeyMap = "us";
      nixpkgs.allowedUnfree = [
        "claude-code"
        "but"
      ];
      systemPackages = [
        "curl"
        "wget"
        "git"
        "man"
        "htop"
        "iotop"
        "tree"
        "jq"
        "python3"
        "ripgrep"
        "unzip"
        "gh"
        "bun"
        "fh"
        "repowise"
        "repowise-nix"
        "llm-agents.cli-proxy-api"
        "llm-agents.but"
        "uv"
      ];
      hardware = {
        importNotDetected = true;
        initrdAvailableKernelModules = [
          "xhci_pci"
          "ahci"
          "nvme"
          "thunderbolt"
          "usbhid"
          "usb_storage"
          "sd_mod"
          "sr_mod"
        ];
        initrdKernelModules = [ ];
        kernelModules = [ "kvm-intel" ];
        kernelParams = [
          "zfs.zfs_arc_max=17179869184"
          "nvme_core.default_ps_max_latency_us=0"
        ];
        kernelSysctl = {
          "vm.swappiness" = 0;
        };
        zfsForceImportRoot = false;
        extraModulePackages = [ ];
        boot = {
          efiCanTouchVariables = true;
          systemdBootEnable = true;
          fallbackSync = {
            enable = true;
            source = "/boot/";
            target = "/boot-fallback/";
          };
        };
        enableRedistributableFirmware = true;
        cpu.intel.updateMicrocodeFromRedistributableFirmware = true;
        graphics = {
          enable = true;
          extraPackages = [
            "intel-media-driver"
            "vpl-gpu-rt"
            "intel-compute-runtime"
          ];
        };
        swapDevices = [ ];
        cpuFreqGovernor = "schedutil";
        zfsMaintenance = {
          autoScrub = true;
          trim = true;
        };
      };
      storage.zfs = true;
      storage.diskoConfigPath = null;
      storage.diskoDevices = {
        disk = {
          nvme0 = {
            type = "disk";
            device = "/dev/disk/by-id/nvme-eui.0025384751a0ee3b";
            content = {
              type = "gpt";
              partitions = {
                ESP = {
                  size = "1G";
                  type = "EF00";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                    mountOptions = [
                      "fmask=0022"
                      "dmask=0022"
                    ];
                  };
                };
                zfs = {
                  size = "100%";
                  content = {
                    type = "zfs";
                    pool = "rpool";
                  };
                };
              };
            };
          };
          nvme1 = {
            type = "disk";
            device = "/dev/disk/by-id/nvme-eui.0025384841a151b4";
            content = {
              type = "gpt";
              partitions = {
                ESP = {
                  size = "1G";
                  type = "EF00";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot-fallback";
                    mountOptions = [
                      "fmask=0022"
                      "dmask=0022"
                      "nofail"
                    ];
                  };
                };
                zfs = {
                  size = "100%";
                  content = {
                    type = "zfs";
                    pool = "rpool";
                  };
                };
              };
            };
          };
        };
        zpool = {
          rpool = {
            type = "zpool";
            mode = "mirror";
            options = {
              ashift = "12";
              autotrim = "on";
            };
            rootFsOptions = {
              # ZFS property on the pool root dataset: do not mount it anywhere.
              # This is the only place "none" belongs; disko's zpool-level
              # `mountpoint` attribute expects an absolute path or null and would
              # reject the literal string "none".
              mountpoint = "none";
              acltype = "posixacl";
              xattr = "sa";
              compression = "lz4";
            };
            datasets = {
              "root/nixos" = {
                type = "zfs_fs";
                mountpoint = "/";
                options = {
                  mountpoint = "legacy";
                  # Ephemeral NixOS system dataset — disable auto-snapshot here
                  # only, leaving data datasets untouched so future snapshot
                  # tooling can opt them in explicitly.
                  "com.sun:auto-snapshot" = "false";
                };
              };
              "nix" = {
                type = "zfs_fs";
                mountpoint = "/nix";
                options = {
                  mountpoint = "legacy";
                  compression = "zstd";
                };
              };
              "var" = {
                type = "zfs_fs";
                mountpoint = "/var";
                options = {
                  mountpoint = "legacy";
                };
              };
              "data" = {
                type = "zfs_fs";
                options = {
                  mountpoint = "none";
                };
              };
              "data/hermes" = {
                type = "zfs_fs";
                mountpoint = "/var/lib/hermes";
                options = {
                  mountpoint = "legacy";
                  recordsize = "16K";
                };
              };
              "data/backup" = {
                type = "zfs_fs";
                mountpoint = "/data/backup";
                options = {
                  mountpoint = "legacy";
                  compression = "zstd";
                  recordsize = "1M";
                  atime = "off";
                  sync = "disabled";
                };
              };
            };
          };
        };
      };
      platform.virtualisation = {
        docker = {
          enable = true;
          storageDriver = "zfs";
          autoPruneDates = "weekly";
        };
        libvirt.enable = true;
        rootEquivalentGroups = [
          "docker"
          "libvirtd"
        ];
        packages = [
          "docker-compose"
          "lazydocker"
          "virtiofsd"
        ];
      };
      platform.provisioning = {
        soul = {
          enable = true;
          after = [
            "hermes-agent-setup"
            "setupSecrets"
          ];
          secretName = "hermes-soul-md";
          relativePath = ".hermes/SOUL.md";
          directoryMode = "0750";
          fileMode = "0640";
        };
        githubAuth = {
          enable = true;
          after = [
            "hermes-agent-setup"
            "setupSecrets"
            "users"
          ];
          secretName = "hermes-env";
          tokenVariable = "GITHUB_TOKEN";
          username = "yui-hermes";
          gitCredentialsRelativePath = ".git-credentials";
          ghConfigRelativeDir = ".config/gh";
        };
      };
      services.hermesAgent = {
        enable = true;
        addToSystemPackages = true;
        extraDependencyGroups = [ "messaging" ];
        extraPackages = [
          "playwright-driver.browsers"
          "ffmpeg"
          "ripgrep"
          "libopus"
          "claude-code"
          "codex"
          "bun"
          "linear-cli"
          "fh"
          "repowise"
          "repowise-nix"
          "llm-agents.omp"
          "llm-agents.agent-browser"
          "mcp-nixos"
        ];
        environment = {
          DISCORD_ALLOWED_USERS = "185292472836947968";
          DISCORD_HOME_CHANNEL = "1493934973009526884";
        };
        environmentSecretNames = [ "hermes-env" ];
        model = {
          provider = "openai-codex";
          default = "gpt-5.5";
          baseUrl = "https://api.openai.com/v1/responses";
        };
        fallbackModel = {
          provider = "openrouter";
          model = "openai/gpt-5.5";
          baseUrl = "https://openrouter.ai/api/v1";
        };
        terminal = {
          backend = "local";
          timeout = 180;
        };
        platformToolsets.cli = [
          "search"
          "browser"
          "terminal"
          "file"
          "code_execution"
          "vision"
          "image_gen"
          "tts"
          "skills"
          "todo"
          "memory"
          "session_search"
          "clarify"
          "delegation"
          "cronjob"
          "messaging"
        ];
        tts = {
          provider = "elevenlabs";
          elevenlabs = {
            voiceId = "cgSgspJ2msm6clMCkdW9";
            modelId = "eleven_flash_v2_5";
          };
        };
        discord = {
          requireMention = true;
          autoThread = true;
          reactions = true;
          historyBackfill = true;
          allowedChannels = [
            "1493930581090762833"
            "1493930714687869028"
          ];
          freeResponseChannels = [ ];
          homeChannel = "1493934973009526884";
        };
        groupSessionsPerUser = true;
        memory = {
          memoryEnabled = true;
          userProfileEnabled = true;
        };
        compression = {
          enabled = true;
          threshold = 0.85;
        };
        agent.maxTurns = 100;
        checkpoints = {
          enabled = true;
          maxSnapshots = 50;
        };
        mcpServers.nixos.enable = true;
        runtime = {
          unsetEnvironment = [ "MESSAGING_CWD" ];
          timeoutStopSec = 240;
        };
      };

      services.hermesAgentPlugins = {
        pythonPackageSet = "python312Packages";
        rtkHermes = {
          version = "1.2.3";
          hash = "sha256-7YRW6PODrCapfYLFn3DvgHAEME//RGC48GQt+s9ot0s=";
        };
        agentmemory = {
          rev = "1838f4d74c3a0accdd3764e7a8ec155cc140b831";
          hash = "sha256-1fNOAfTnFC7ElRsZbCtTK0ix4HQC1ld4+aDT97Qn4iA=";
        };
        hindsightClient = {
          version = "0.5.4";
          url = "https://files.pythonhosted.org/packages/64/69/30c8252e9b6b04876946f05adf8497b1204f90a77f181e2d9c501dcaa317/hindsight_client-0.5.4.tar.gz";
          hash = "sha256-rcs9+zqxqzSmGdJ8OiqRxCUw6hlxSIpgSh2sLHjVVHs=";
        };
        extraPackages = [ "llm-agents.rtk" ];
        enabledPlugins = [
          "rtk-rewrite"
          "agentmemory"
        ];
      };

      services.netdataMonitoring = {
        enable = true;
        packageVersion = "2.10.3";
        packageSrcHash = "sha256-ryX+C3zuY7vONPeB4ocXDPttU5aSYbj1ThTosCSxmys=";
        ndMcpVendorHash = "sha256-jyCTp52Dc2IuRwzGT+sHFljO30oqAMfe3xVdEpV+R2c=";
        goPluginVendorHash = "sha256-HRe1bcVIQVzwPZnGlAK5A8AO1VTcjFajkPwBVdl4UIA=";
        cargoVendorHash = "sha256-mxFpT95e+NMqjJOIRqM+yKHGQHfpWmIFHqFNiiiqXOY=";
        jfCargoVendorHash = "sha256-6spr8WRt2G6tzaUQACxIcVMoDNKOFTg6rSPEOihMgLE=";
        agentApiUrl = "http://127.0.0.1:19999";
        bindTo = "127.0.0.1";
        disabledPlugins = {
          freeipmi = "no";
          "logs-management" = "no";
        };
        logAllowlist = [
          "netdata.service"
          "hermes-agent.service"
          "agentmemory.service"
          "hindsight-embed.service"
          "omp-auth-gateway.service"
        ];
        logDefaultLines = 120;
        logMaxLines = 500;
        postgresSocketDir = "/var/run/postgresql";
      };
      services.agentMemory = {
        enable = true;
        stateDir = "/var/lib/agentmemory";
        cacheDir = "/var/cache/agentmemory";
        restPort = 3111;
        streamsPort = 3112;
        viewerPort = 3113;
        enginePort = 49134;
        llm = {
          enable = true;
          baseUrl = "http://127.0.0.1:4000";
          model = "gpt-5.4-mini";
          timeoutMs = 120000;
          embeddingProvider = "local";
        };
      };
      services.ompAuthGateway = {
        brokerPort = 9000;
        gatewayPort = 4000;
        bindHost = "127.0.0.1";
        adminHome = "/home/admin";
        primaryModel = "gpt-5.5";
        fallbackModel = "gemini-3-flash-agent";
        delegationModel = "gemini-3-flash-agent";
        localApiKey = "local-auth-gateway";
      };
      services.hindsightMemory = {
        enable = false;
        activationAfter = [ "hermes-agent-setup" ];
        llm = {
          provider = "openai";
          baseUrl = "http://10.0.0.102:8317/v1";
          model = "gpt-5.4-mini";
          timeout = 120;
        };
        llama = {
          enable = false;
          modelPath = "/var/lib/hermes/models/google_gemma-4-E2B-it-Q6_K_L.gguf";
          host = "127.0.0.1";
          port = 8080;
          contextSize = 8192;
          threads = 10;
          enableEmbeddings = true;
          pooling = "mean";
          chatTemplate = null;
        };
        providerConfig = {
          mode = "local_external";
          api_url = "http://127.0.0.1:8888";
          # Keep a static fallback for older provider versions, but prefer the
          # template below so Hermes profiles do not blend memories into one bank.
          bank_id = "hermes";
          bank_id_template = "hermes-{profile}";
          budget = "mid";
        };
      };
      secrets = {
        defaultSopsFile = "den/hosts/nixos-hermes/secrets/payload/hermes-secrets.yaml";
        ageKeyFile = "/etc/secrets/age.key";
        # The SSH host key is itself a sops-managed secret; using it as an age
        # identity creates a circular dependency. Use only the age key file.
        ageSshKeyPaths = [ ];
        bindings = {
          ssh_host_ed25519_key = {
            sopsFile = "den/hosts/nixos-hermes/secrets/payload/ssh_host_ed25519_key.enc";
            format = "binary";
            owner = "root";
            mode = "0600";
            path = "/etc/ssh/ssh_host_ed25519_key";
          };
          "hermes-env" = {
            owner = "hermes";
            mode = "0400";
          };
          omp-auth-broker-token = {
            owner = "admin";
            mode = "0400";
          };
          cliproxyapi-key = {
            sopsFile = "den/hosts/nixos-hermes/secrets/payload/cliproxyapi-key.enc";
            format = "binary";
            owner = "agentmemory";
            group = "agentmemory";
            mode = "0400";
          };
          hermes-soul-md = {
            sopsFile = "den/hosts/nixos-hermes/secrets/payload/soul.md";
            format = "binary";
            owner = "hermes";
            mode = "0440";
          };
          netdata-claim-conf = {
            sopsFile = "den/hosts/nixos-hermes/secrets/payload/netdata-claim.conf";
            format = "binary";
            owner = "root";
            group = "netdata";
            mode = "0440";
          };
        };
      };

      users.root = {
        sshAuthorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQ0xpYd/EJnMyHW36xmWodb0DPoMHf4LpQAl7xheMRE"
        ];
      };

      users.admin = {
        normalUser = true;
        description = "System Admin";
        hasHomeManagerConfig = true;
        home = "/home/admin";
        createHome = true;
        homeMode = "700";
        extraGroups = [
          "wheel"
          "networkmanager"
          "hermes"
        ];
        sshAuthorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG3neF+6qsDFb1pwr06mdW0mqMcxquAGNsjbGiG/Rj23"
        ];
        classes = [ "homeManager" ];
        homePackages = [
          "bat"
          "glow"
          "yazi"
          "llm-agents.omp"
          "home-manager"
        ];
      };

      users.hermes = {
        description = "Hermes account";
        hasHomeManagerConfig = true;
        sshAuthorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0inarJ3Em+01Y22ahDmJkbhevhwuFFrWyIEl0CjkzE"
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBN6C8GPyeaAKWwkSqNXzDDQEzeGQ21IWGhAa+xFqNIHlQ7uDNA/9wc8A4tXO3ckp7seY+84aXAAyCQyfrrmKSbQ= #ssh.id"
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCBs4KwCYyBZxsb02nyw9tRMsgOtfBuyM3mBh4varuvKc4JO4rzN1Iq2cXHyy0ttYIaDg52iPWlTM+O6pdpvVcE= #ssh.id"
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNWfcMlHqWVodM+9A5ZnVEvw7zkDJMHW2cUw4Ru4v+8a3ot+QHH038uLkTl95SIL5XaKslAqe+gyqcZ4X6BPhtA= #ssh.id"
        ];
        classes = [ "homeManager" ];
      };

      # VM-only fixture facts used by tests to prove same-user mixed Den/native
      # Home Manager migration. Production rendering gates the user explicitly
      # with den.fixtures.denPoc.enable instead of treating it as inventory.
      users.den-poc = {
        normalUser = true;
        hasHomeManagerConfig = true;
        home = "/home/den-poc";
        createHome = true;
        classes = [ ];
      };
    };

  den.aspects.nixos-hermes.os =
    {
      lib,
      pkgs,
      modulesPath,
      config,
      ...
    }:
    let
      vitePlusToolchain = with pkgs; [
        nodejs
        (pkgs.vite-plus or pkgs.hello)
      ];
      vitePlusHome = {
        sessionPath = [
          "$HOME/.vite-plus/bin"
        ];
      };
      vitePlusBashInit = ''
        if [ -f "$HOME/.vite-plus/env" ]; then
          . "$HOME/.vite-plus/env"
        fi
      '';
      sharedUserConfig = {
        manual.manpages.enable = false;
        programs.bash.enable = true;
        programs.bash.initExtra = vitePlusBashInit;
      };
      direnvConfig = {
        programs.direnv.enable = true;
        programs.direnv.nix-direnv.enable = true;
      };
    in
    let
      hermesLocales = pkgs.runCommand "hermes-agent-locales" { } ''
        cp -R ${inputs.hermes-agent}/locales $out
      '';

      # nixpkgs patches CPython with no-ldconfig.patch — ctypes.util._findSoname_ldconfig
      # unconditionally returns None. LD_LIBRARY_PATH and ldconfig cache approaches are
      # both dead. Inject a sitecustomize.py via PYTHONPATH that patches find_library("opus")
      # to return the Nix store path directly before any user code runs.
      #
      # Hermes 0.14.0's agent.i18n resolves catalogs at site-packages/locales, but
      # the Nix package omits the repo-level locales/ directory. Point the runtime
      # i18n loader at the same locked source revision so gateway slash commands do
      # not render raw keys such as gateway.resume.list_header.
      #
      # Hermes 0.15.x's pyproject still includes only `hermes_cli`, not
      # `hermes_cli.*`, so uv2nix omits the new `hermes_cli.proxy` subpackage from
      # the sealed environment. Extend the installed package path to the locked
      # source tree instead of patching generated/bundled output.
      opusCtypesShim = pkgs.writeTextDir "sitecustomize.py" ''
        import ctypes.util as _cu
        from pathlib import Path as _Path

        _OPUS_PATH = "${pkgs.libopus}/lib/libopus.so.0"
        _HERMES_LOCALES = _Path("${hermesLocales}")
        _HERMES_CLI_SOURCE = "${inputs.hermes-agent}/hermes_cli"
        _orig = _cu.find_library

        def find_library(name, *args, **kwargs):
            if name == "opus":
                return _OPUS_PATH
            return _orig(name, *args, **kwargs)

        _cu.find_library = find_library

        try:
            import hermes_cli as _hermes_cli

            if hasattr(_hermes_cli, "__path__") and _HERMES_CLI_SOURCE not in _hermes_cli.__path__:
                _hermes_cli.__path__.append(_HERMES_CLI_SOURCE)
        except ImportError:
            pass

        try:
            import agent.i18n as _hermes_i18n

            _hermes_i18n._locales_dir = lambda: _HERMES_LOCALES
            _hermes_i18n.reset_language_cache()
        except ImportError:
            pass
      '';
      packageByName =
        name: lib.attrByPath (lib.splitString "." name) (throw "Unknown Den system package ${name}") pkgs;
      platformVirtualisationPackages = builtins.map packageByName host.platform.virtualisation.packages;
      hardwareExtraModulePackages = builtins.map packageByName host.hardware.extraModulePackages;
      hardwareGraphicsExtraPackages = builtins.map packageByName host.hardware.graphics.extraPackages;
      hermesExtraPackages = builtins.map packageByName host.services.hermesAgent.extraPackages;
      hermesPluginExtraPackages = builtins.map packageByName host.services.hermesAgentPlugins.extraPackages;
      adminHomePackages = builtins.map packageByName admin.homePackages;
      repoPath = path: ../. + "/${path}";
      renderSecret =
        _name: secret:
        lib.filterAttrs (_: value: value != null) {
          sopsFile = if secret.sopsFile == null then null else repoPath secret.sopsFile;
          inherit (secret)
            format
            owner
            group
            mode
            path
            ;
        };
      hermesAgentModule =
        {
          config,
          lib,
          pkgs,
          ...
        }:

        {
          services.hermes-agent = {
            enable = host.services.hermesAgent.enable;
            addToSystemPackages = host.services.hermesAgent.addToSystemPackages;

            # Optional Hermes pyproject dependency groups included in the sealed Python
            # environment. The Discord gateway adapter lives in the upstream
            # "messaging" group; without it the service can run while Discord is absent.
            extraDependencyGroups = host.services.hermesAgent.extraDependencyGroups;

            # Packages required by enabled toolsets.
            # playwright-driver.browsers: NixOS-wrapped browser binaries for the browser toolset.
            # ffmpeg: audio processing for ElevenLabs TTS voice bubble delivery.
            # ripgrep: fast search used by file and terminal toolsets.
            # libopus: pins the store path referenced by the opus ctypes shim (see the Den-rendered package overlay).
            # claude-code, codex: AI coding agents — nixpkgs provides both as of May 2026.
            # bun: JavaScript runtime, package manager, and build tool.
            # linear-cli: API-key-backed Linear control plane for headless agent workflows.
            # fh: official FlakeHub CLI for flake input discovery and conversion.
            # omp: terminal-based multi-model coding agent from numtide/llm-agents.nix overlay.
            # agent-browser: headless browser automation CLI from llm-agents.nix (built from source, auto-updated daily).
            # repowise: local repo-intelligence/orientation map for nixos-hermes work.
            extraPackages = hermesExtraPackages;

            # Non-secret environment variables injected into the service.
            # PLAYWRIGHT_BROWSERS_PATH tells hermes's internal Playwright where NixOS
            # placed the browser binaries (standard PATH lookup does not work for Playwright).
            # DISCORD_ALLOWED_USERS: user allowlisting is env-only; settings.discord has no
            # equivalent key — placing it here keeps it out of the secret bundle.
            # DISCORD_HOME_CHANNEL: 0.10.0 gateway reads this env var to determine the home
            # channel; settings.discord.home_channel populates config.yaml but is not consulted
            # by the runtime check.
            environment = {
              PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
              DISCORD_ALLOWED_USERS = host.services.hermesAgent.environment.DISCORD_ALLOWED_USERS;
              DISCORD_HOME_CHANNEL = host.services.hermesAgent.environment.DISCORD_HOME_CHANNEL;
            };

            # API keys merged into $HERMES_HOME/.env at activation.
            # Current keys include Discord/ElevenLabs/OpenRouter/Linear/GitHub plus scoped
            # tool credentials such as GEMINI_API_KEY and REPOWISE_OPENAI_*.
            environmentFiles = builtins.map (name: config.sops.secrets.${name}.path) (
              builtins.filter (
                name: builtins.hasAttr name config.sops.secrets
              ) host.services.hermesAgent.environmentSecretNames
            );

            settings = {
              model = {
                # OpenAI Codex provider uses the Responses API endpoint.
                base_url = lib.mkDefault host.services.hermesAgent.model.baseUrl;
                default = lib.mkDefault host.services.hermesAgent.model.default;
                provider = lib.mkDefault host.services.hermesAgent.model.provider;
              };

              # Automatic provider failover on rate limits, overload, or connection
              # failures. OpenRouter uses an API key (not OAuth) so it survives
              # Nous inference token expiry or refresh failures.
              fallback_model = {
                provider = lib.mkDefault host.services.hermesAgent.fallbackModel.provider;
                base_url = lib.mkDefault host.services.hermesAgent.fallbackModel.baseUrl;
                model = lib.mkDefault host.services.hermesAgent.fallbackModel.model;
              };

              # Replaces the deprecated MESSAGING_CWD environment variable.
              # The upstream module still injects MESSAGING_CWD into the service;
              # UnsetEnvironment below removes it so hermes reads only config.yaml.
              terminal = {
                backend = host.services.hermesAgent.terminal.backend;
                cwd = config.services.hermes-agent.workingDirectory;
                timeout = host.services.hermesAgent.terminal.timeout;
              };

              # Capabilities the agent may invoke.
              # Use per-platform toolsets so CLI keeps search/browser/terminal/file/etc.
              # without inheriting the web toolset's LLM summarization path.
              platform_toolsets.cli = host.services.hermesAgent.platformToolsets.cli;

              tts = {
                provider = host.services.hermesAgent.tts.provider;
                elevenlabs = {
                  voice_id = host.services.hermesAgent.tts.elevenlabs.voiceId;
                  model_id = host.services.hermesAgent.tts.elevenlabs.modelId;
                };
              };

              # Discord operational behaviour — not secrets; live here, not in hermes-env.
              # DISCORD_BOT_TOKEN remains in the hermes-env sops secret.
              # DISCORD_ALLOWED_USERS is wired via environment above (config.yaml has no allowed_users key).
              discord = {
                require_mention = host.services.hermesAgent.discord.requireMention; # Respond only when @mentioned
                auto_thread = host.services.hermesAgent.discord.autoThread; # Isolate each conversation in a thread
                reactions = host.services.hermesAgent.discord.reactions; # Emoji reactions for processing state
                # Keep the upstream default explicit: if Discord presence expands beyond
                # the restricted Hermes channels below, review this context-ingestion boundary.
                history_backfill = host.services.hermesAgent.discord.historyBackfill;
                allowed_channels = host.services.hermesAgent.discord.allowedChannels;
                free_response_channels = host.services.hermesAgent.discord.freeResponseChannels; # Channels that respond without @mention
                home_channel = host.services.hermesAgent.discord.homeChannel; # hermes-home (text)
              };

              # One session per user per channel — prevents session bleed in shared servers.
              group_sessions_per_user = host.services.hermesAgent.groupSessionsPerUser;

              memory = {
                memory_enabled = host.services.hermesAgent.memory.memoryEnabled;
                user_profile_enabled = host.services.hermesAgent.memory.userProfileEnabled;
              };

              # Compress context at 50% of the model's context window.
              compression = {
                enabled = host.services.hermesAgent.compression.enabled;
                threshold = host.services.hermesAgent.compression.threshold;
              };

              agent = {
                max_turns = host.services.hermesAgent.agent.maxTurns; # Hard ceiling on turns per conversation
              };

              checkpoints = {
                enabled = host.services.hermesAgent.checkpoints.enabled;
                max_snapshots = host.services.hermesAgent.checkpoints.maxSnapshots;
              };
            };
            mcpServers = {
              nixos = lib.mkIf host.services.hermesAgent.mcpServers.nixos.enable {
                command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
                args = [ ];
              };
            };
          };

          # MESSAGING_CWD is deprecated in 0.10.0 in favour of terminal.cwd in config.yaml.
          # The upstream nixosModules.nix still sets it unconditionally; UnsetEnvironment
          # removes it from the service environment so hermes sees only the config.yaml value.
          systemd.services.hermes-agent = {
            # The upstream module writes config.yaml under mutable HERMES_HOME during
            # activation. Changes to that file do not necessarily change the systemd unit,
            # so NixOS can refresh config without restarting the long-lived gateway. Force
            # a restart when runtime config inputs change so provider/plugin/MCP cutovers
            # actually reach the running process.
            restartTriggers = [
              (pkgs.writeText "hermes-agent-runtime-config-trigger.json" (
                builtins.toJSON {
                  settings = config.services.hermes-agent.settings;
                  mcpServers = config.services.hermes-agent.mcpServers;
                  extraPlugins = map toString config.services.hermes-agent.extraPlugins;
                }
              ))
            ];

            serviceConfig = {
              UnsetEnvironment = host.services.hermesAgent.runtime.unsetEnvironment;
              # Hermes gateway drain timeout is 180s; keep systemd's stop budget longer so
              # rebuild/test restarts do not SIGKILL the gateway mid-drain.
              TimeoutStopSec = host.services.hermesAgent.runtime.timeoutStopSec;
            };
          };

          # opusCtypesShim patches ctypes.util.find_library("opus") at interpreter startup.
          # sitecustomize.py is imported by site.py before any user code; PYTHONPATH prepends
          # our directory so it takes precedence over any existing sitecustomize in site-packages.
          systemd.services.hermes-agent.environment = {
            PYTHONPATH = toString pkgs.opusCtypesShim;
          };

        };
      hermesAgentPluginsModule =
        { pkgs, ... }:

        let
          # Match Hermes 0.12.0's sealed Python environment. The pinned nixpkgs
          # default is Python 3.13, while the Hermes wrapper currently runs Python 3.12;
          # using pkgs.python3Packages would build plugins for the wrong interpreter.
          pythonPackages = pkgs.${host.services.hermesAgentPlugins.pythonPackageSet};

          rtkHermes = pythonPackages.buildPythonPackage rec {
            pname = "rtk-hermes";
            version = host.services.hermesAgentPlugins.rtkHermes.version;

            src = pkgs.fetchFromGitHub {
              owner = "ogallotti";
              repo = "rtk-hermes";
              rev = "v${version}";
              hash = host.services.hermesAgentPlugins.rtkHermes.hash;
            };

            pyproject = true;
            build-system = [ pythonPackages.setuptools ];
            # rtk-hermes declares no mandatory third-party runtime Python dependencies
            # in pyproject.toml. Its runtime integration shells out to the `rtk` binary,
            # which is supplied through services.hermes-agent.extraPackages below.
            dependencies = [ ];

            pythonImportsCheck = [ "rtk_hermes" ];
          };

          aiohttpRetryForHermes = pythonPackages.aiohttp-retry.overridePythonAttrs (_old: {
            # Hermes' sealed runtime already supplies aiohttp. Propagating it from this
            # extra package collides with the sealed environment; only add the missing
            # aiohttp_retry distribution to the Hermes wrapper. Newer nixpkgs Python
            # builders use `dependencies`; clear both fields so the generated wrapper
            # closure cannot reintroduce aiohttp through either spelling.
            dependencies = [ ];
            propagatedBuildInputs = [ ];
            doCheck = false;
            pythonImportsCheck = [ ];
            dontCheckRuntimeDeps = true;
          });

          agentmemorySource = pkgs.fetchFromGitHub {
            owner = "rohitg00";
            repo = "agentmemory";
            rev = host.services.hermesAgentPlugins.agentmemory.rev;
            hash = host.services.hermesAgentPlugins.agentmemory.hash;
          };

          agentmemoryHermesPlugin = pkgs.runCommand "agentmemory-hermes-plugin-0.9.21" { } ''
            mkdir -p $out
            cp -R ${agentmemorySource}/integrations/hermes/. $out/
          '';

          hindsightClient = pythonPackages.buildPythonPackage rec {
            pname = "hindsight-client";
            version = host.services.hermesAgentPlugins.hindsightClient.version;

            src = pkgs.fetchurl {
              url = host.services.hermesAgentPlugins.hindsightClient.url;
              hash = host.services.hermesAgentPlugins.hindsightClient.hash;
            };

            pyproject = true;
            build-system = [ pythonPackages.hatchling ];

            dependencies = [ ];
            dontCheckRuntimeDeps = true;

            # These are already present in the Hermes sealed runtime. Keep them available
            # for this package's build-time import check without propagating duplicate
            # distributions into services.hermes-agent.extraPythonPackages, where the
            # Hermes build intentionally rejects sealed-venv collisions.
            nativeCheckInputs = with pythonPackages; [
              aiohttp
              aiohttp-retry
              pydantic
              python-dateutil
              typing-extensions
              urllib3
            ];

            pythonImportsCheck = [ "hindsight_client" ];
          };
        in
        {
          services.hermes-agent = {
            # Entry-point plugins are installed into the Hermes Python wrapper via
            # extraPythonPackages. Directory plugins should use extraPlugins instead;
            # see docs/guides/HERMES_PLUGINS_NIX.md for the repeatable workflow.
            extraPythonPackages = [
              rtkHermes
              aiohttpRetryForHermes
              hindsightClient
            ];

            # rtk-hermes rewrites terminal commands through the rtk binary. Keep the
            # executable in the Hermes service PATH declaratively instead of relying on
            # mutable state in the service home.
            extraPackages = hermesPluginExtraPackages;

            extraPlugins = [ agentmemoryHermesPlugin ];

            settings.plugins.enabled = host.services.hermesAgentPlugins.enabledPlugins;
          };
        };
      netdataMonitoringModule =
        # Netdata Cloud agent plus a native CLI for Hermes access to metrics/logs.
        {
          config,
          lib,
          pkgs,
          ...
        }:

        let
          netdataPackageBase = inputs.nixpkgs-llama.legacyPackages.${pkgs.stdenv.hostPlatform.system}.netdata;

          # Netdata Cloud currently requires 2.10.3 for security fixes, while both the
          # primary FlakeHub nixpkgs input and nixpkgs-llama still package older agents.
          # Keep this scoped to the Netdata package; do not move the host to NixOS stable.
          netdataPackage = netdataPackageBase.overrideAttrs (
            finalAttrs: previousAttrs: {
              version = host.services.netdataMonitoring.packageVersion;

              src = pkgs.fetchFromGitHub {
                owner = "netdata";
                repo = "netdata";
                rev = "v${finalAttrs.version}";
                hash = host.services.netdataMonitoring.packageSrcHash;
                fetchSubmodules = true;
              };

              passthru =
                previousAttrs.passthru
                // (
                  let
                    ndMcpBridge = pkgs.buildGoModule {
                      pname = "${finalAttrs.pname}-nd-mcp";
                      inherit (finalAttrs) version src;
                      sourceRoot = "${finalAttrs.src.name}/src/web/mcp/bridges/stdio-golang";
                      vendorHash = host.services.netdataMonitoring.ndMcpVendorHash;
                      proxyVendor = true;
                      doCheck = false;
                      subPackages = [ "." ];
                      ldflags = [
                        "-s"
                        "-w"
                      ];
                      meta = finalAttrs.meta // {
                        description = "Netdata Model Context Protocol (MCP) stdio bridge";
                        mainProgram = "nd-mcp-bridge";
                        license = lib.licenses.gpl3Only;
                      };
                    };
                    goPlugin = pkgs.buildGoModule {
                      pname = "${finalAttrs.pname}-go-plugins";
                      inherit (finalAttrs) version src;
                      sourceRoot = "${finalAttrs.src.name}/src/go/plugin/go.d";
                      vendorHash = host.services.netdataMonitoring.goPluginVendorHash;
                      proxyVendor = true;
                      doCheck = false;
                      ldflags = [
                        "-s"
                        "-w"
                        "-X main.version=${finalAttrs.version}"
                      ];
                      meta = finalAttrs.meta // {
                        description = "Netdata orchestrator for data collection modules written in Go";
                        mainProgram = "godplugin";
                        license = lib.licenses.gpl3Only;
                      };
                    };
                  in
                  {
                    # These attr names are consumed by the upstream Netdata CMake build as
                    # file:// GOPROXY inputs, so they must stay as module proxy trees.
                    nd-mcp = ndMcpBridge.goModules;
                    netdata-go-modules = goPlugin.goModules;

                    # Export the runnable packages separately for host/Hermes usage.
                    nd-mcp-bridge = ndMcpBridge;
                    netdata-go-plugin = goPlugin;
                  }
                );

              cargoRoot = "src/crates";
              cargoDeps = pkgs.symlinkJoin {
                name = "cargo-vendor-dir";
                paths = [
                  (pkgs.rustPlatform.fetchCargoVendor {
                    inherit (finalAttrs)
                      pname
                      version
                      src
                      cargoRoot
                      ;
                    hash = host.services.netdataMonitoring.cargoVendorHash;
                  })
                  (pkgs.rustPlatform.fetchCargoVendor {
                    pname = "${finalAttrs.pname}-nd-jf";
                    inherit (finalAttrs) version src;
                    cargoRoot = "${finalAttrs.cargoRoot}/jf";
                    hash = host.services.netdataMonitoring.jfCargoVendorHash;
                  })
                ];
              };
            }
          );

          # Local Netdata agent API endpoint consumed by netdata-observe. This is not
          # the operator dashboard; Netdata Cloud is the dashboard/control plane.
          netdataAgentApiUrl = host.services.netdataMonitoring.agentApiUrl;

          netdataWaitForApi = pkgs.writeShellScript "wait-for-netdata-up" ''
            until [ "$(${netdataPackage}/bin/netdatacli ping)" = pong ]; do
              sleep 0.5
            done
          '';

          netdataCloudClaim = pkgs.writeShellApplication {
            name = "netdata-cloud-claim";
            runtimeInputs = [
              pkgs.curl
              pkgs.jq
              pkgs.gawk
            ];
            text = ''
              set -euo pipefail

              base_url="${netdataAgentApiUrl}"
              claim_conf="$CREDENTIALS_DIRECTORY/netdata_claim_conf"
              session_key_file="/var/lib/netdata/netdata_random_session_id"

              status="$(curl --fail --silent --show-error "$base_url/api/v3/claim" | jq -r '.cloud.status')"
              if [[ "$status" == "online" ]]; then
                exit 0
              fi

              if [[ ! -r "$session_key_file" ]]; then
                echo "Netdata claim session key is not readable: $session_key_file" >&2
                exit 1
              fi

              key="$(< "$session_key_file")"
              token="$(awk -F= '/^[[:space:]]*token[[:space:]]*=/{ sub(/^[[:space:]]*/, "", $2); print $2; exit }' "$claim_conf")"
              url="$(awk -F= '/^[[:space:]]*url[[:space:]]*=/{ sub(/^[[:space:]]*/, "", $2); print $2; exit }' "$claim_conf")"
              rooms="$(awk -F= '/^[[:space:]]*rooms[[:space:]]*=/{ sub(/^[[:space:]]*/, "", $2); print $2; exit }' "$claim_conf")"

              if [[ -z "$token" || -z "$url" ]]; then
                echo "Netdata claim configuration is missing token or url" >&2
                exit 1
              fi

              query="key=$(jq -rn --arg v "$key" '$v|@uri')&token=$(jq -rn --arg v "$token" '$v|@uri')&url=$(jq -rn --arg v "$url" '$v|@uri')"
              if [[ -n "$rooms" ]]; then
                query="$query&rooms=$(jq -rn --arg v "$rooms" '$v|@uri')"
              fi

              result="$(curl --fail --silent --show-error "$base_url/api/v3/claim?$query")"
              success="$(jq -r '.success // false' <<<"$result")"
              cloud_status="$(jq -r '.cloud.status // "unknown"' <<<"$result")"
              if [[ "$success" != "true" && "$cloud_status" != "online" ]]; then
                jq . <<<"$result" >&2
                exit 1
              fi
            '';
          };

          netdataPostgresConfig = pkgs.writeText "netdata-postgres.conf" ''
            # Netdata's documented PostgreSQL setup is a local `netdata` database role
            # with pg_monitor (or pg_read_all_stats), then a file-managed go.d job.
            # Use peer auth over the local Unix socket; no SOPS password is needed for
            # this host-local collector.
            update_every: 1
            autodetection_retry: 60
            jobs:
              - name: local
                dsn: 'host=${host.services.netdataMonitoring.postgresSocketDir} dbname=postgres user=netdata'
                collect_databases_matching: '*'
          '';

          netdataObserve = pkgs.writeShellApplication {
            name = "netdata-observe";
            runtimeInputs = [
              pkgs.curl
              pkgs.jq
              pkgs.systemd
            ];
            text = ''
              set -euo pipefail

              base_url="''${NETDATA_AGENT_API_URL:-${netdataAgentApiUrl}}"

              usage() {
                cat <<'EOF'
              Usage: netdata-observe <command> [args]

              Commands:
                info                         Show Netdata agent info
                alarms                       Show active alarms
                charts                       List available charts
                allmetrics                   Dump all metrics as JSON
                data <chart> [seconds]       Fetch chart data, default window: 300s
                api <path>                   Call an arbitrary Netdata API path
                logs [unit] [lines]          Show bounded systemd logs, default: netdata.service ${toString host.services.netdataMonitoring.logDefaultLines}

              Examples:
                netdata-observe data system.cpu 600
                netdata-observe api /api/v1/data?chart=system.ram\&after=-300\&format=json
                netdata-observe logs netdata.service 200
              EOF
              }

              get() {
                local target="$1"
                if [[ "$target" == http://* || "$target" == https://* ]]; then
                  echo "Error: Absolute URLs are not permitted. Only paths are allowed." >&2
                  exit 1
                fi
                [[ "$target" == /* ]] || target="/$target"
                curl --fail --silent --show-error "$base_url$target" | jq .
              }

              command="''${1:-}"
              if [[ -z "$command" ]]; then
                usage
                exit 2
              fi
              shift

              case "$command" in
                info)
                  get /api/v1/info
                  ;;
                alarms)
                  get /api/v1/alarms
                  ;;
                charts)
                  get /api/v1/charts
                  ;;
                allmetrics)
                  get /api/v1/allmetrics?format=json
                  ;;
                data)
                  chart="''${1:-}"
                  seconds="''${2:-300}"
                  if [[ -z "$chart" ]]; then
                    echo "chart is required" >&2
                    usage >&2
                    exit 2
                  fi
                  chart_encoded=$(jq -rn --arg v "$chart" '$v|@uri')
                  get "/api/v1/data?chart=$chart_encoded&after=-$seconds&format=json"
                  ;;
                api)
                  target="''${1:-}"
                  if [[ -z "$target" ]]; then
                    echo "API path is required" >&2
                    usage >&2
                    exit 2
                  fi
                  get "$target"
                  ;;
                logs)
                  unit="''${1:-netdata.service}"
                  lines="''${2:-120}"

                  if [[ $# -gt 2 ]]; then
                    echo "Error: logs accepts only [unit] [lines]; arbitrary journalctl arguments are not allowed." >&2
                    exit 2
                  fi

                  case "$unit" in
                    ${lib.concatStringsSep "|" host.services.netdataMonitoring.logAllowlist})
                      ;;
                    *)
                      echo "Error: unit is not allowlisted for bounded log access: $unit" >&2
                      exit 2
                      ;;
                  esac

                  if ! [[ "$lines" =~ ^[0-9]+$ ]]; then
                    echo "Error: lines must be an integer between 1 and 500." >&2
                    exit 2
                  fi
                  # Bash arithmetic and journalctl both reject leading-zero values such as 08.
                  # Normalize through explicit base 10 so otherwise-valid decimal input is safe.
                  lines_decimal=$((10#$lines))
                  if (( lines_decimal < 1 || lines_decimal > ${toString host.services.netdataMonitoring.logMaxLines} )); then
                    echo "Error: lines must be between 1 and ${toString host.services.netdataMonitoring.logMaxLines}." >&2
                    exit 2
                  fi

                  journalctl -u "$unit" -n "$lines_decimal" --no-pager --output=short-iso
                  ;;
                -h|--help|help)
                  usage
                  ;;
                *)
                  echo "unknown command: $command" >&2
                  usage >&2
                  exit 2
                  ;;
              esac
            '';
          };
        in
        {
          services.netdata = {
            enable = host.services.netdataMonitoring.enable;

            # Use the current Netdata stable release without pinning this host to a
            # NixOS/nixpkgs stable channel.
            package = netdataPackage;

            enableAnalyticsReporting = false;

            config = {
              plugins = {
                # This host has no IPMI/BMC hardware; out-of-band management is AMT/vPro.
                # Disable the enterprise-server hardware collector instead of letting it
                # emit recurring FreeIPMI internal errors.
                freeipmi = host.services.netdataMonitoring.disabledPlugins.freeipmi;

                # The Nix package exposes systemd-journal/OTel log functions, but does
                # not ship logs-management.plugin. Without this explicit disable, the
                # generated setuid wrapper directory advertises a missing plugin and
                # Netdata logs an exit-127 collector failure on every restart.
                "logs-management" = host.services.netdataMonitoring.disabledPlugins."logs-management";
              };

              web = {
                # No local dashboard exposure: Netdata Cloud is the operator UI. Keep
                # the host API loopback-only for diagnostics and netdata-observe.
                "bind to" = host.services.netdataMonitoring.bindTo;
              };
            };

            configDir = {
              # Netdata's scripts.d plugin watches this directory even when no jobs are
              # configured. The NixOS module renders /etc/netdata/conf.d from only
              # configDir entries, so expose the packaged empty/example directory to
              # avoid one journal error per minute about a missing path.
              "scripts.d" = "${netdataPackage}/share/netdata/conf.d/scripts.d";
            }
            // lib.optionalAttrs config.services.postgresql.enable {
              "go.d/postgres.conf" = netdataPostgresConfig;
            };
          };

          services.hermes-agent.mcpServers.netdata = {
            command = lib.getExe netdataPackage.passthru.nd-mcp-bridge;
            args = [ "ws://127.0.0.1:19999/mcp" ];
          };

          # Interactive Hermes/TUI tool calls do not inherit hermes-agent.service's
          # SupplementaryGroups. Grant the login user raw journal read access, then keep
          # agent-facing log retrieval bounded through netdata-observe's allowlist/line cap.
          users.users.hermes.extraGroups = [ "systemd-journal" ];

          services.postgresql.ensureUsers = lib.mkIf config.services.postgresql.enable [
            {
              name = "netdata";
            }
          ];

          systemd.services.netdata-postgres-monitoring-setup = lib.mkIf config.services.postgresql.enable {
            description = "Grant PostgreSQL monitoring privileges to Netdata";
            wantedBy = [ "multi-user.target" ];
            after = [
              "postgresql.service"
              "postgresql-setup.service"
            ];
            requires = [
              "postgresql.service"
              "postgresql-setup.service"
            ];

            serviceConfig = {
              Type = "oneshot";
              User = "postgres";
              Group = "postgres";
              ExecStart = "${config.services.postgresql.package}/bin/psql -d postgres -tAc 'GRANT pg_monitor TO netdata;'";
            };
          };

          environment.systemPackages = [
            netdataPackage
            netdataObserve
          ];

          systemd.services.netdata.serviceConfig = {
            SupplementaryGroups = [
              # Netdata Cloud's systemd-journal function is served by the Netdata agent,
              # not by Hermes. Grant the agent read-only journal group access so log
              # exploration works without exposing the local dashboard beyond loopback.
              "systemd-journal"
            ];
            ExecStartPost = [ "${netdataWaitForApi}" ];
          }
          // lib.optionalAttrs (config.sops.secrets ? "netdata-claim-conf") {
            LoadCredential = [
              "netdata_claim_conf:${config.sops.secrets.netdata-claim-conf.path}"
            ];
            ExecStartPre = "+${pkgs.writeShellScript "netdata-install-cloud-claim-conf" ''
              set -euo pipefail
              install -D -o root -g netdata -m 0640 \
                "$CREDENTIALS_DIRECTORY/netdata_claim_conf" \
                /etc/netdata/claim.conf
            ''}";
            ExecStartPost = [
              "${netdataWaitForApi}"
              "+${lib.getExe netdataCloudClaim}"
            ];
          };

          systemd.services.hermes-agent.serviceConfig.SupplementaryGroups = [
            # Tool calls run under hermes-agent.service. Grant the service read-only
            # journal access for netdata-observe logs without making Netdata a startup
            # dependency of Hermes or making journal access a general property of every
            # hermes login/session.
            "systemd-journal"
          ];
        };
      agentMemoryModule =
        # Host-local Agent Memory parallel-observer service.
        {
          config,
          lib,
          pkgs,
          ...
        }:

        let
          cfg = config.services.agentmemory;
          stateDir = host.services.agentMemory.stateDir;
          dataDir = "${stateDir}/data";
          cacheDir = host.services.agentMemory.cacheDir;
          transformersCacheDir = "${cacheDir}/transformers";
          restPort = host.services.agentMemory.restPort;
          streamsPort = host.services.agentMemory.streamsPort;
          normalizedLlmBaseUrl = lib.removeSuffix "/" cfg.llm.baseUrl;
          viewerPort = host.services.agentMemory.viewerPort;
          enginePort = host.services.agentMemory.enginePort;
          yaml = pkgs.formats.yaml { };
          agentmemoryRoot = "${cfg.package}/lib/node_modules/@agentmemory/agentmemory";
          transformersRuntimeConfig = pkgs.writeText "agentmemory-transformers-runtime.mjs" ''
            // Import the package's ESM main file so this mutates the same env object
            // used by Agent Memory's later @xenova/transformers pipeline imports.
            import { env } from "${agentmemoryRoot}/node_modules/@xenova/transformers/src/transformers.js";

            env.cacheDir = process.env.TRANSFORMERS_CACHE || "${transformersCacheDir}";
            env.useFSCache = true;
          '';
          startScript = pkgs.writeShellScript "agentmemory-start" ''
            set -eu
            ${lib.optionalString cfg.llm.enable ''
              # OMP's auth gateway is loopback-only and runs with --no-auth. Agent Memory
              # still needs a non-empty OpenAI-compatible key to select its LLM path, so
              # use a local sentinel instead of depending on the retired LAN proxy
              # secret route.
              export OPENAI_API_KEY=local-auth-gateway
            ''}
            exec ${lib.getExe cfg.package.passthru.iii-engine} --config ${iiiConfig}
          '';
          iiiConfig = yaml.generate "agentmemory-iii-config.yaml" {
            workers = [
              {
                name = "iii-worker-manager";
                config = {
                  host = "127.0.0.1";
                  port = enginePort;
                };
              }
              {
                name = "iii-http";
                config = {
                  port = restPort;
                  host = "127.0.0.1";
                  default_timeout = 180000;
                  cors = {
                    allowed_origins = [
                      "http://localhost:${toString restPort}"
                      "http://localhost:${toString viewerPort}"
                      "http://127.0.0.1:${toString restPort}"
                      "http://127.0.0.1:${toString viewerPort}"
                    ];
                    allowed_methods = [
                      "GET"
                      "POST"
                      "PUT"
                      "DELETE"
                      "OPTIONS"
                    ];
                  };
                };
              }
              {
                name = "iii-state";
                config.adapter = {
                  name = "kv";
                  config = {
                    store_method = "file_based";
                    file_path = "${dataDir}/state_store.db";
                  };
                };
              }
              {
                name = "iii-queue";
                config.adapter.name = "builtin";
              }
              {
                name = "iii-pubsub";
                config.adapter.name = "local";
              }
              {
                name = "iii-cron";
                config.adapter = {
                  name = "kv";
                  config = {
                    store_method = "file_based";
                    file_path = "${dataDir}/cron_store.db";
                  };
                };
              }
              {
                name = "iii-stream";
                config = {
                  port = streamsPort;
                  host = "127.0.0.1";
                  adapter = {
                    name = "kv";
                    config = {
                      store_method = "file_based";
                      file_path = "${dataDir}/stream_store";
                    };
                  };
                };
              }
              {
                name = "iii-observability";
                config = {
                  enabled = true;
                  service_name = "agentmemory";
                  exporter = "memory";
                  sampling_ratio = 1.0;
                  metrics_enabled = true;
                  logs_enabled = true;
                  logs_console_output = true;
                };
              }
              {
                name = "iii-exec";
                config.exec = [
                  "${pkgs.nodejs}/bin/node ${agentmemoryRoot}/dist/index.mjs"
                ];
              }
            ];
          };
          readyCheck = pkgs.writeShellScript "agentmemory-ready-check" ''
            set -eu
            for _ in $(seq 1 30); do
              if ${pkgs.curl}/bin/curl -fsS --max-time 2 http://127.0.0.1:${toString restPort}/agentmemory/livez >/dev/null; then
                exit 0
              fi
              sleep 1
            done
            echo "agentmemory REST endpoints did not become ready" >&2
            exit 1
          '';
        in
        {
          options.services.agentmemory = {
            enable = lib.mkEnableOption "Agent Memory local parallel-observer service";

            package = lib.mkPackageOption pkgs "agentmemory" { };

            llm = {
              enable = lib.mkEnableOption "Agent Memory LLM enrichment through the local OMP OpenAI-compatible auth gateway";

              baseUrl = lib.mkOption {
                type = lib.types.str;
                default = host.services.agentMemory.llm.baseUrl;
                description = ''
                  Root URL for Agent Memory's OpenAI-compatible provider. Agent Memory
                  0.9.21 appends /v1/chat/completions itself, so this must not include
                  /v1. Use the local OMP auth gateway root instead of the old LAN
                  CLIProxyAPI route so compression does not depend on cross-host
                  networking after rebuilds.
                '';
              };

              model = lib.mkOption {
                type = lib.types.str;
                default = host.services.agentMemory.llm.model;
                description = "OpenAI-compatible chat model routed by CLIProxyAPI.";
              };

              timeoutMs = lib.mkOption {
                type = lib.types.ints.positive;
                default = host.services.agentMemory.llm.timeoutMs;
                description = "Agent Memory LLM request timeout in milliseconds.";
              };

              embeddingProvider = lib.mkOption {
                type = lib.types.str;
                default = host.services.agentMemory.llm.embeddingProvider;
                description = ''
                  Embedding provider used while OPENAI_API_KEY is present for chat LLM
                  calls. Keep this explicit so adding the proxy key does not
                  accidentally route embedding traffic through CLIProxyAPI.
                '';
              };
            };
          };

          config = lib.mkMerge [
            {
              services.agentmemory.enable = lib.mkDefault host.services.agentMemory.enable;
              services.agentmemory.llm.enable = lib.mkDefault host.services.agentMemory.llm.enable;
            }

            (lib.mkIf cfg.enable {
              assertions = [
                {
                  assertion =
                    !cfg.llm.enable
                    || lib.hasPrefix "http://" cfg.llm.baseUrl
                    || lib.hasPrefix "https://" cfg.llm.baseUrl;
                  message = "services.agentmemory.llm.baseUrl must start with http:// or https://.";
                }
                {
                  assertion = !cfg.llm.enable || !(lib.hasSuffix "/v1" normalizedLlmBaseUrl);
                  message = "services.agentmemory.llm.baseUrl must be the proxy root; Agent Memory appends /v1/chat/completions itself.";
                }
              ];

              users.users.agentmemory = {
                isSystemUser = true;
                group = "agentmemory";
                home = stateDir;
                createHome = false;
              };

              users.groups.agentmemory = { };

              services.hermes-agent = {
                environment = {
                  AGENTMEMORY_URL = "http://127.0.0.1:${toString restPort}";
                  # Keep the upstream plaintext-bearer guard enabled. The plugin allows
                  # loopback HTTP, but will fail closed if a future secret-bearing config
                  # drifts to plaintext HTTP on a non-loopback host.
                  AGENTMEMORY_REQUIRE_HTTPS = "1";
                };

                # Agent Memory is now the active Hermes memory provider. Hindsight was
                # useful as a spike, but its retain/consolidation path proved too costly
                # and fragile to keep in the live assistant loop. Hermes' MemoryProvider
                # loader selects user-installed providers by their directory name under
                # $HERMES_HOME/plugins, and the NixOS module installs extraPlugins as
                # nix-managed-* symlinks. The plugin's internal name remains
                # "agentmemory" for the general plugin manager, but memory.provider must
                # match the symlink name for load_memory_provider() to find it.
                settings.memory.provider = "nix-managed-agentmemory-hermes-plugin";

                mcpServers.agentmemory = {
                  command = lib.getExe cfg.package;
                  args = [ "mcp" ];
                  env.AGENTMEMORY_URL = "http://127.0.0.1:${toString restPort}";
                  connect_timeout = 30;
                  timeout = 120;
                };
              };

              systemd.services.agentmemory = {
                description = "Agent Memory parallel observer";
                after = [
                  "network.target"
                  "omp-auth-gateway.service"
                ];
                wants = [ "omp-auth-gateway.service" ];
                wantedBy = [ "multi-user.target" ];

                environment = {
                  HOME = stateDir;
                  AGENTMEMORY_URL = "http://127.0.0.1:${toString restPort}";
                  AGENTMEMORY_VIEWER_URL = "http://127.0.0.1:${toString viewerPort}";
                  AGENTMEMORY_ALLOW_AGENT_SDK = "false";
                  AGENTMEMORY_AUTO_COMPRESS = "true";
                  GRAPH_EXTRACTION_ENABLED = "true";
                  CONSOLIDATION_ENABLED = "true";
                  AGENTMEMORY_INJECT_CONTEXT = "true";
                  AGENTMEMORY_TOOLS = "core";
                  AGENTMEMORY_III_VERSION = cfg.package.passthru.iii-engine.version;
                  III_REST_PORT = toString restPort;
                  III_STREAMS_PORT = toString streamsPort;
                  III_STREAM_PORT = toString streamsPort;
                  III_VIEWER_PORT = toString viewerPort;
                  III_ENGINE_URL = "ws://127.0.0.1:${toString enginePort}";
                  VIEWER_ALLOWED_ORIGINS = "http://127.0.0.1:${toString restPort},http://127.0.0.1:${toString viewerPort},http://localhost:${toString restPort},http://localhost:${toString viewerPort}";
                  TRANSFORMERS_CACHE = transformersCacheDir;
                  XDG_CACHE_HOME = cacheDir;
                  NODE_OPTIONS = "--import ${transformersRuntimeConfig}";
                }
                // lib.optionalAttrs cfg.llm.enable {
                  OPENAI_BASE_URL = cfg.llm.baseUrl;
                  OPENAI_MODEL = cfg.llm.model;
                  AGENTMEMORY_LLM_TIMEOUT_MS = toString cfg.llm.timeoutMs;
                  OPENAI_TIMEOUT_MS = toString cfg.llm.timeoutMs;
                  EMBEDDING_PROVIDER = cfg.llm.embeddingProvider;
                };

                # iii-exec launches configured commands via `sh -c`; keep the
                # service PATH minimal, but include the shell and engine runtime used
                # by Agent Memory's worker process.
                path = [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.curl
                  cfg.package.passthru.iii-engine
                ];

                restartTriggers = [
                  iiiConfig
                  readyCheck
                  startScript
                  transformersRuntimeConfig
                  cfg.package
                ];

                serviceConfig = {
                  Type = "simple";
                  User = "agentmemory";
                  Group = "agentmemory";
                  StateDirectory = [
                    "agentmemory"
                    "agentmemory/data"
                  ];
                  StateDirectoryMode = "0700";
                  CacheDirectory = [
                    "agentmemory"
                    "agentmemory/transformers"
                  ];
                  CacheDirectoryMode = "0700";
                  WorkingDirectory = stateDir;
                  ExecStart = startScript;
                  ExecStartPost = readyCheck;
                  # iii/Node workers can leave cgroup children behind after the main
                  # engine exits. Do not let rebuild/test wait systemd's default 90s
                  # stop timeout for a memory observer; SIGKILL cleanup is acceptable
                  # after a short graceful drain.
                  TimeoutStopSec = "10s";
                  Restart = "on-failure";
                  RestartSec = "5s";

                  NoNewPrivileges = true;
                  PrivateTmp = true;
                  ProtectSystem = "strict";
                  ProtectHome = true;
                  ReadWritePaths = [
                    stateDir
                    cacheDir
                  ];
                  RestrictAddressFamilies = [
                    "AF_UNIX"
                    "AF_INET"
                    "AF_INET6"
                  ];
                };
              };
            })
          ];
        };
      ompAuthGatewayModule =
        # Host-local OMP auth broker/gateway for Hermes inference.
        {
          config,
          lib,
          pkgs,
          ...
        }:

        let
          brokerPort = host.services.ompAuthGateway.brokerPort;
          gatewayPort = host.services.ompAuthGateway.gatewayPort;
          bindHost = host.services.ompAuthGateway.bindHost;
          adminHome = host.services.ompAuthGateway.adminHome;
          tokenFile = "${adminHome}/.omp/auth-broker.token";
          omp = lib.getExe pkgs.llm-agents.omp;

          brokerUrl = "http://${bindHost}:${toString brokerPort}";
          gatewayBaseUrl = "http://${bindHost}:${toString gatewayPort}/v1";

          adminXdgEnvironment = {
            HOME = adminHome;
            XDG_DATA_HOME = "${adminHome}/.local/share";
            XDG_STATE_HOME = "${adminHome}/.local/state";
            XDG_CACHE_HOME = "${adminHome}/.cache";
          };

          installBrokerToken = pkgs.writeShellScript "omp-auth-broker-install-token" ''
            set -eu
            ${pkgs.coreutils}/bin/install -d -m 0700 -o admin -g users ${adminHome}/.omp
            ${pkgs.coreutils}/bin/install -m 0600 -o admin -g users ${config.sops.secrets.omp-auth-broker-token.path} ${tokenFile}
          '';

          brokerReadyCheck = pkgs.writeShellScript "omp-auth-broker-ready" ''
            set -eu
            token_file=${tokenFile}
            for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
              if [ -r "$token_file" ]; then
                token="$(${pkgs.coreutils}/bin/cat "$token_file")"
                if ${pkgs.curl}/bin/curl -fsS --max-time 2 \
                  -H "Authorization: Bearer $token" \
                  ${brokerUrl}/v1/healthz >/dev/null; then
                  exit 0
                fi
              fi
              ${pkgs.coreutils}/bin/sleep 1
            done
            echo "OMP auth broker did not become ready" >&2
            exit 1
          '';

          gatewayReadyCheck = pkgs.writeShellScript "omp-auth-gateway-ready" ''
            set -eu
            for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
              if ${pkgs.curl}/bin/curl -fsS --max-time 2 ${gatewayBaseUrl}/models >/dev/null; then
                exit 0
              fi
              ${pkgs.coreutils}/bin/sleep 1
            done
            echo "OMP auth gateway did not expose a model catalog" >&2
            exit 1
          '';
        in
        {
          services.hermes-agent = {
            settings = {
              model = {
                # Route Hermes through OMP's loopback auth-gateway so OMP owns OAuth
                # refresh and provider-specific Codex request shaping. Do not use the
                # Hermes openai-codex provider here: Hermes 0.14 resolves that provider
                # through its own ChatGPT OAuth credential pool and ignores model.base_url.
                provider = "custom";
                default = host.services.ompAuthGateway.primaryModel;
                base_url = gatewayBaseUrl;
                api_mode = "codex_responses";
                openai_runtime = "auto";
              };

              fallback_model = {
                # Keep fallback behind the same local gateway, but route it to a
                # different upstream provider/model so OpenAI OAuth exhaustion does not
                # take out both primary and failover. Clear api_mode here so Hermes
                # does not reuse the primary Codex Responses shaping for Antigravity.
                provider = "custom";
                base_url = gatewayBaseUrl;
                model = host.services.ompAuthGateway.fallbackModel;
                api_mode = "";
              };

              delegation = {
                # Run subagents through the same admin-owned OMP auth gateway as the
                # main Hermes model, but on the Antigravity model lane. This lets us
                # smoke gateway routing independently from the controller model.
                provider = "custom";
                base_url = gatewayBaseUrl;
                model = host.services.ompAuthGateway.delegationModel;
                api_key = host.services.ompAuthGateway.localApiKey;
                api_mode = "";
              };
            };
          };

          systemd.services = lib.mkIf (config.sops.secrets ? "omp-auth-broker-token") {
            omp-auth-broker = {
              description = "OMP OAuth auth broker";
              after = [
                "network-online.target"
                "sops-nix.service"
              ];
              wants = [
                "network-online.target"
                "sops-nix.service"
              ];
              wantedBy = [ "multi-user.target" ];

              environment = adminXdgEnvironment;

              path = [
                pkgs.coreutils
                pkgs.curl
              ];

              restartTriggers = [
                pkgs.llm-agents.omp
                brokerReadyCheck
                installBrokerToken
              ];

              serviceConfig = {
                Type = "simple";
                User = "admin";
                WorkingDirectory = adminHome;
                ExecStartPre = "+${installBrokerToken}";
                ExecStart = "${omp} auth-broker serve --bind=${bindHost}:${toString brokerPort}";
                ExecStartPost = brokerReadyCheck;
                Restart = "on-failure";
                RestartSec = "5s";
                UMask = "0077";
                NoNewPrivileges = true;
                RestrictAddressFamilies = [
                  "AF_UNIX"
                  "AF_INET"
                  "AF_INET6"
                ];
              };
            };

            omp-auth-gateway = {
              description = "OMP loopback auth gateway";
              after = [
                "network-online.target"
                "omp-auth-broker.service"
              ];
              requires = [ "omp-auth-broker.service" ];
              wants = [ "network-online.target" ];
              wantedBy = [ "multi-user.target" ];

              environment = adminXdgEnvironment // {
                OMP_AUTH_BROKER_URL = brokerUrl;
              };

              path = [
                pkgs.coreutils
                pkgs.curl
              ];

              restartTriggers = [
                pkgs.llm-agents.omp
                gatewayReadyCheck
              ];

              serviceConfig = {
                Type = "simple";
                User = "admin";
                WorkingDirectory = adminHome;
                ExecStart = "${omp} auth-gateway serve --bind=${bindHost}:${toString gatewayPort} --no-auth";
                ExecStartPost = gatewayReadyCheck;
                Restart = "on-failure";
                RestartSec = "5s";
                UMask = "0077";
                NoNewPrivileges = true;
                RestrictAddressFamilies = [
                  "AF_UNIX"
                  "AF_INET"
                  "AF_INET6"
                ];
              };
            };

            hermes-agent = {
              after = [ "omp-auth-gateway.service" ];
              requires = [ "omp-auth-gateway.service" ];
            };
          };
        };
      hindsightEmbedModule =
        {
          config,
          lib,
          pkgs,
          ...
        }:

        let
          cfg = config.services.hindsightMemory;
          types = lib.types;

          # Use the configured Hermes package's sealed runtime Python instead of a
          # fixed /nix/store path. This follows any future services.hermes-agent.package
          # override and avoids coupling this host module to one Hermes build output.
          hermesEnvPython = "${config.services.hermes-agent.package.passthru.hermesVenv}/bin/python3";

          # Writable Hindsight API venv path. Created at service start by ExecStartPre.
          # This venv belongs to hindsight-embed.service itself. Agent-facing Hermes
          # imports `hindsight_client` from services.hermes-agent.extraPythonPackages,
          # not by adding this mutable venv to the Hermes service PYTHONPATH.
          hindsightVenv = "/var/lib/hermes/.venv";

          serviceEnvFile = pkgs.writeText "hindsight-embed.env" (
            lib.concatStringsSep "\n" [
              "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
              "HINDSIGHT_API_LLM_PROVIDER=${cfg.llm.provider}"
              "HINDSIGHT_API_LLM_BASE_URL=${cfg.llm.baseUrl}"
              "HINDSIGHT_API_LLM_MODEL=${cfg.llm.model}"
              # Hindsight's retain prompt is schema-heavy; keep a generous timeout for
              # remote proxy retries while relying on a stronger model than local CPU llama.cpp.
              "HINDSIGHT_API_LLM_TIMEOUT=${toString cfg.llm.timeout}"
              "HINDSIGHT_API_RETAIN_MAX_COMPLETION_TOKENS=4096"
              "HINDSIGHT_API_RETAIN_EXTRACTION_MODE=custom"
              ''HINDSIGHT_API_RETAIN_CUSTOM_INSTRUCTIONS=Return exactly one JSON object with a top-level "facts" array; never return a bare array. Extract only durable personal, preference, role, project, and operational facts useful across future sessions. Do not extract transient command attempts, retry counts, curl invocations, timeouts, or debugging steps as facts. If a sentence contains both transient steps and a durable lesson, extract only the durable lesson. Use fact_type="world" for facts about people, organizations, preferences, roles, projects, tools, or external state. Use fact_type="assistant" only for first-person actions performed by the narrator/assistant. For each fact include what, when, where, who, why, fact_type, fact_kind, and entities.''
              "HINDSIGHT_API_DATABASE_URL=postgresql:///hermes?host=/run/postgresql"
              "HINDSIGHT_API_EMBEDDINGS_PROVIDER=openai"
              "HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY=local"
              "HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL=http://${cfg.llama.host}:${toString cfg.llama.port}/v1"
              "HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL=${builtins.baseNameOf cfg.llama.modelPath}"
              # Avoid the default local sentence-transformers reranker; the spike uses
              # Hindsight's dependency-free RRF passthrough until ONE-24 wires a richer
              # provider intentionally.
              "HINDSIGHT_API_RERANKER_PROVIDER=rrf"
              "HINDSIGHT_API_PORT=8888"
              "HINDSIGHT_API_HOST=127.0.0.1"
            ]
            + "\n"
          );

          llmPreflightPython = pkgs.writeText "hindsight-llm-preflight.py" ''
            import json
            import os
            import sys
            import urllib.error
            import urllib.request

            base_url = os.environ["HINDSIGHT_API_LLM_BASE_URL"].rstrip("/")
            model = os.environ["HINDSIGHT_API_LLM_MODEL"]
            api_key = os.environ["HINDSIGHT_API_LLM_API_KEY"]
            models_url = f"{base_url}/models"

            request = urllib.request.Request(
                models_url,
                method="GET",
                headers={"Authorization": f"Bearer {api_key}"},
            )
            try:
                with urllib.request.urlopen(request, timeout=10) as response:
                    body = response.read().decode("utf-8")
            except urllib.error.HTTPError as exc:
                detail = exc.read().decode("utf-8", errors="replace")[:500]
                raise SystemExit(f"Hindsight LLM preflight failed: HTTP {exc.code} from {models_url}: {detail}") from exc
            except urllib.error.URLError as exc:
                raise SystemExit(f"Hindsight LLM preflight failed: connection error to {models_url}: {exc.reason}") from exc

            try:
                payload = json.loads(body)
            except json.JSONDecodeError as exc:
                raise SystemExit(f"Hindsight LLM preflight failed: invalid JSON from {models_url}: {body[:500]}") from exc

            if not isinstance(payload, dict):
                raise SystemExit(
                    f"Hindsight LLM preflight failed: expected JSON object from {models_url}, "
                    f"got {type(payload).__name__}"
                )

            data = payload.get("data") or []
            if not isinstance(data, list):
                raise SystemExit(
                    f"Hindsight LLM preflight failed: expected JSON array at {models_url} data field, "
                    f"got {type(data).__name__}"
                )

            model_ids = {str(item.get("id")) for item in data if isinstance(item, dict) and item.get("id")}
            if model not in model_ids:
                sample = ", ".join(sorted(model_ids)[:20])
                raise SystemExit(f"Missing configured Hindsight LLM model {model!r} from {models_url}; sample models: {sample}")

            print(f"Hindsight LLM preflight OK: {model} listed by {models_url}")
          '';

          postgresInitScript = pkgs.writeShellScript "hindsight-postgres-init" ''
            set -euo pipefail
            ${config.services.postgresql.package}/bin/psql -v ON_ERROR_STOP=1 -d hermes <<'SQL'
            CREATE EXTENSION IF NOT EXISTS vector;

            CREATE OR REPLACE FUNCTION public.schemas_with_pending_work()
            RETURNS SETOF text AS $$
            DECLARE
              r RECORD;
              has_work BOOLEAN;
            BEGIN
              IF to_regclass('public.async_operations') IS NOT NULL THEN
                SELECT EXISTS(
                  SELECT 1
                  FROM public.async_operations
                  WHERE status = 'pending'
                    AND task_payload IS NOT NULL
                  LIMIT 1
                ) INTO has_work;
                IF has_work THEN
                  RETURN NEXT NULL::text;
                END IF;
              END IF;

              FOR r IN SELECT nspname FROM pg_namespace WHERE nspname LIKE 'tenant_%' LOOP
                BEGIN
                  EXECUTE format(
                    $query$SELECT EXISTS(SELECT 1 FROM %I.async_operations WHERE status = 'pending' AND task_payload IS NOT NULL LIMIT 1)$query$,
                    r.nspname
                  ) INTO has_work;
                  IF has_work THEN
                    RETURN NEXT r.nspname;
                  END IF;
                EXCEPTION WHEN OTHERS THEN
                  NULL;
                END;
              END LOOP;
            END
            $$ LANGUAGE plpgsql STABLE;
            SQL
          '';

          recoveryPreflightScript = pkgs.writeShellScript "hindsight-embed-recovery-preflight" ''
            set -euo pipefail
            export HINDSIGHT_API_LLM_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/cliproxyapi-key")"

            # Release work claimed by a previous API/worker process before accepting
            # post-rebuild retain requests. This deployment runs a single Hindsight API
            # worker; revisit this if the database ever backs multiple live workers.
            if [ "$(${config.services.postgresql.package}/bin/psql "$HINDSIGHT_API_DATABASE_URL" -tAc "select to_regclass('public.async_operations')")" = "async_operations" ]; then
              ${hindsightVenv}/bin/python3 -m hindsight_api.admin.cli decommission-workers --yes
            fi

            # Fail fast before systemd marks the service started. The /models check
            # proves the OpenAI-compatible route, credential, and configured model, while
            # the outer timeout prevents a stuck dependency probe from greenwashing unit
            # startup with no API socket bound.
            ${pkgs.coreutils}/bin/timeout 15s ${hindsightVenv}/bin/python3 ${llmPreflightPython}
          '';

          startScript = pkgs.writeShellScript "hindsight-embed-start" ''
            set -euo pipefail
            export HINDSIGHT_API_LLM_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/cliproxyapi-key")"
            exec ${hindsightVenv}/bin/hindsight-api --host 127.0.0.1 --port 8888
          '';

          setupScript = pkgs.writeShellScript "hindsight-embed-setup" ''
            set -euo pipefail
            VENV="${hindsightVenv}"
            PYTHON="${hermesEnvPython}"
            PYTHON_MARKER="$VENV/.hermes-python"
            CURRENT_PYTHON="$(readlink -f "$PYTHON")"
            needs_install=0

            # Recreate the venv when Hermes' sealed Python changes after a NixOS rebuild.
            # A venv's bin/python3 resolves to the underlying CPython interpreter, not the
            # hermes-agent-env wrapper used to create it, so track the creator path in a
            # marker file instead of comparing readlink targets directly.
            if [ ! -f "$VENV/bin/python3" ] || [ ! -f "$PYTHON_MARKER" ] || [ "$(cat "$PYTHON_MARKER")" != "$CURRENT_PYTHON" ]; then
              echo "Creating/refreshing hindsight venv at $VENV..."
              "$PYTHON" -m venv --system-site-packages --clear "$VENV"
              printf '%s\n' "$CURRENT_PYTHON" > "$PYTHON_MARKER"
              needs_install=1
            fi

            # Avoid reinstalling wheels on every rebuild. The venv is mutable host state,
            # so exact version checks are enough to refresh only when pins change.
            if [ "$needs_install" -eq 0 ]; then
              "$VENV/bin/python3" -c 'from importlib.metadata import version; expected = {"hindsight-api-slim": "0.5.4", "hindsight-client": "0.5.4", "hindsight-embed": "0.5.4"}; raise SystemExit(0 if all(version(pkg) == want for pkg, want in expected.items()) else 1)' || needs_install=1
            fi

            if [ "$needs_install" -eq 1 ]; then
              echo "Installing hindsight packages..."
              ${pkgs.uv}/bin/uv --no-cache pip install \
                --python "$VENV/bin/python3" \
                --quiet \
                "hindsight-api-slim==0.5.4" \
                "hindsight-client==0.5.4" \
                "hindsight-embed==0.5.4"
              echo "hindsight packages ready."
            else
              echo "hindsight packages already at pinned versions."
            fi
          '';

        in
        {
          options.services.hindsightMemory = {
            enable = lib.mkEnableOption "local Hindsight memory spike services";

            llm = {
              provider = lib.mkOption {
                type = types.str;
                default = host.services.hindsightMemory.llm.provider;
                description = "Hindsight LLM provider name. Use openai for OpenAI-compatible proxies.";
              };

              baseUrl = lib.mkOption {
                type = types.str;
                default = host.services.hindsightMemory.llm.baseUrl;
                description = "OpenAI-compatible base URL used for Hindsight retain/reflect LLM calls.";
              };

              model = lib.mkOption {
                type = types.str;
                default = host.services.hindsightMemory.llm.model;
                description = "Model used for Hindsight retain/reflect LLM calls.";
              };

              timeout = lib.mkOption {
                type = types.ints.positive;
                default = host.services.hindsightMemory.llm.timeout;
                description = "Timeout in seconds for Hindsight LLM calls through the external proxy.";
              };
            };
          };

          config = lib.mkIf cfg.enable {
            assertions = [
              {
                assertion = cfg.llama.enable;
                message = "services.hindsightMemory currently keeps local llama.cpp enabled for embeddings; set services.hindsightMemory.llama.enable = true or teach hindsight-embed.nix about an external embeddings provider.";
              }
              {
                assertion = lib.hasPrefix "http://" cfg.llm.baseUrl || lib.hasPrefix "https://" cfg.llm.baseUrl;
                message = "services.hindsightMemory.llm.baseUrl must include an http(s) scheme.";
              }
            ];

            # Postgres instance for hindsight-embed's backing store.
            # hindsight-embed (hindsight-api) manages its own schema; we just provide the server.
            services.postgresql = {
              enable = true;
              # NixOS requires that a database with the same name as the user exists when
              # ensureDBOwnership = true. We therefore name the database after the user
              # ("hermes") and connect over the local Unix socket as the hermes service user.
              # Hindsight stores embeddings with pgvector.
              extensions = ps: [ ps.pgvector ];
              ensureDatabases = [ "hermes" ];
              ensureUsers = [
                {
                  name = "hermes";
                  ensureDBOwnership = true;
                }
              ];
            };

            systemd.services.hindsight-postgres-init = {
              description = "Initialize Hindsight PostgreSQL extensions";
              after = [ "postgresql.service" ];
              before = [ "hindsight-embed.service" ];
              requiredBy = [ "hindsight-embed.service" ];
              requires = [ "postgresql.service" ];

              serviceConfig = {
                Type = "oneshot";
                User = "postgres";
                ExecStart = postgresInitScript;
              };
            };

            systemd.services.hindsight-embed = {
              description = "Hindsight memory server (hindsight-api, local_external mode)";
              wantedBy = [ "multi-user.target" ];
              after = [
                "network.target"
                "postgresql.service"
                "hindsight-postgres-init.service"
              ]
              ++ lib.optionals cfg.llama.enable [ "llama-server.service" ];
              requires = [
                "postgresql.service"
                "hindsight-postgres-init.service"
              ]
              ++ lib.optionals cfg.llama.enable [ "llama-server.service" ];

              restartTriggers = [
                serviceEnvFile
                setupScript
                recoveryPreflightScript
                startScript
              ];

              serviceConfig = {
                Type = "simple";
                User = "hermes";
                StateDirectory = "hermes";
                Restart = "on-failure";
                RestartSec = "5s";
                EnvironmentFile = [ serviceEnvFile ];
                LoadCredential = [ "cliproxyapi-key:${config.sops.secrets.cliproxyapi-key.path}" ];
                ExecStartPre = [
                  setupScript
                  recoveryPreflightScript
                ];
                # Run hindsight-api directly in foreground (no --daemon flag).
                # systemd manages the lifecycle; daemon mode would fork away and break Type=simple.
                ExecStart = startScript;
              };
            };
          };
        };
      hindsightProviderConfig = host.services.hindsightMemory.providerConfig;
      hindsightConfig = pkgs.writeText "hermes-hindsight-config.json" (
        builtins.toJSON hindsightProviderConfig
      );
      hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
      hindsightLlama = config.services.hindsightMemory.llama;
      hindsightLlamaModelName = builtins.baseNameOf hindsightLlama.modelPath;
      hindsightLlamaArgs = [
        "--model"
        hindsightLlama.modelPath
        "--host"
        hindsightLlama.host
        "--port"
        (toString hindsightLlama.port)
        "--ctx-size"
        (toString hindsightLlama.contextSize)
        "--threads"
        (toString hindsightLlama.threads)
      ]
      ++ lib.optionals hindsightLlama.enableEmbeddings (
        [ "--embeddings" ]
        ++ lib.optionals (hindsightLlama.pooling != null) [
          "--pooling"
          hindsightLlama.pooling
        ]
      )
      ++ lib.optionals (hindsightLlama.chatTemplate != null) [
        "--chat-template"
        hindsightLlama.chatTemplate
      ];
    in
    {
      imports =
        lib.optionals host.hardware.importNotDetected [
          (modulesPath + "/installer/scan/not-detected.nix")
        ]
        ++ [
          {
            options = {
              den.fixtures.denPoc.enable = lib.mkEnableOption "VM-only den-poc migration fixture user";

              services.hindsightMemory.llama = {
                enable = lib.mkEnableOption "local llama.cpp inference server for Hindsight memory";
                modelPath = lib.mkOption {
                  type = lib.types.str;
                  default = host.services.hindsightMemory.llama.modelPath;
                  description = "Absolute path to the GGUF model served by llama.cpp.";
                };
                host = lib.mkOption {
                  type = lib.types.str;
                  default = host.services.hindsightMemory.llama.host;
                  description = "Address for llama.cpp's OpenAI-compatible HTTP server.";
                };
                port = lib.mkOption {
                  type = lib.types.port;
                  default = host.services.hindsightMemory.llama.port;
                  description = "TCP port for llama.cpp's OpenAI-compatible HTTP server.";
                };
                contextSize = lib.mkOption {
                  type = lib.types.ints.positive;
                  default = host.services.hindsightMemory.llama.contextSize;
                  description = "Context size passed to llama.cpp.";
                };
                threads = lib.mkOption {
                  type = lib.types.ints.positive;
                  default = host.services.hindsightMemory.llama.threads;
                  description = "CPU threads passed to llama.cpp.";
                };
                enableEmbeddings = lib.mkOption {
                  type = lib.types.bool;
                  default = host.services.hindsightMemory.llama.enableEmbeddings;
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
                  default = host.services.hindsightMemory.llama.pooling;
                  description = "Pooling mode used by llama.cpp when embeddings are enabled.";
                };
                chatTemplate = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = host.services.hindsightMemory.llama.chatTemplate;
                  description = "Chat template passed to llama.cpp; set to null to let llama.cpp infer it.";
                };
              };
            };
          }
          hindsightEmbedModule
          hermesAgentModule
          hermesAgentPluginsModule
          netdataMonitoringModule
          agentMemoryModule
          ompAuthGatewayModule
        ];

      # Allow specific unfree packages needed by the host while letting NixOS VM
      # tests keep nixpkgs' read-only defaults.
      nixpkgs.config = lib.mkDefault {
        allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) host.nixpkgs.allowedUnfree;
      };

      nixpkgs.overlays = [
        # llm-agents.nix provides claude-code, codex, omp, agent-browser, and many more.
        # Use the default overlay for the fast-moving main input so npm packages build
        # with llm-agents' own compatible nixpkgs; GitButler is overridden below from
        # a separate pinned input.
        inputs.llm-agents.overlays.default
        (final: prev: {
          # Exposed via overlay so consumers (hermes-agent.nix) can reference
          # pkgs.opusCtypesShim without packages.nix coupling to any service.
          inherit opusCtypesShim;

          linear-cli = prev.buildGoModule rec {
            pname = "linear-cli";
            version = "1.8.1";

            src = prev.fetchFromGitHub {
              owner = "joa23";
              repo = "linear-cli";
              rev = "v${version}";
              hash = "sha256-7Yk/UzbZ5P7awctHwFNVUMEgFN3fUATqHZZm9RdSLfE=";
            };

            vendorHash = "sha256-Ype8lW/3wbIbbFhPMwXEnm+9tEMPYMqPIxg8ykeK8v0=";

            subPackages = [ "cmd/linear" ];
            env.CGO_ENABLED = 0;
            ldflags = [ "-X github.com/joa23/linear-cli/internal/cli.Version=v${version}" ];
            preCheck = ''
              unset LINEAR_API_KEY
            '';

            meta = {
              description = "Token-efficient Linear CLI optimized for AI agent workflows";
              homepage = "https://github.com/joa23/linear-cli";
              license = lib.licenses.mit;
              mainProgram = "linear";
              platforms = lib.platforms.linux ++ lib.platforms.darwin;
            };
          };

          iii-engine = prev.stdenvNoCC.mkDerivation rec {
            pname = "iii-engine";
            version = "0.11.2";

            src = prev.fetchzip {
              url = "https://github.com/iii-hq/iii/releases/download/iii%2Fv${version}/iii-x86_64-unknown-linux-gnu.tar.gz";
              hash = "sha256-Sg9wnmCWrlPYaE6m6Qla+r3WTi0iSbkiwix1ziYjAsM=";
            };

            nativeBuildInputs = [ prev.autoPatchelfHook ];
            buildInputs = [ prev.stdenv.cc.cc.lib ];

            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              runHook preInstall
              install -Dm0755 iii $out/bin/iii
              runHook postInstall
            '';

            meta = {
              description = "iii engine runtime used by Agent Memory";
              homepage = "https://github.com/iii-hq/iii";
              license = lib.licenses.asl20;
              mainProgram = "iii";
              platforms = [ "x86_64-linux" ];
            };
          };

          repowise = inputs.repowise-nix.packages.${prev.stdenv.hostPlatform.system}.repowise;
          repowise-nix = inputs.repowise-nix.packages.${prev.stdenv.hostPlatform.system}.repowise-nix;
          vite-plus = prev.callPackage ../packages/vite-plus { };

          agentmemory =
            let
              version = "0.9.21";
              src = prev.fetchzip {
                url = "https://registry.npmjs.org/@agentmemory/agentmemory/-/agentmemory-${version}.tgz";
                hash = "sha256-5uTldqCNGCXH3Wz1piBwCIfgh1MS1Vy+vsvFQNMlyPA=";
              };
              nodeModules = prev.stdenvNoCC.mkDerivation {
                pname = "agentmemory-node-modules";
                inherit version src;

                nativeBuildInputs = [
                  prev.cacert
                  prev.nodejs
                ];

                dontConfigure = true;
                dontBuild = true;

                installPhase = ''
                  runHook preInstall
                  export HOME="$TMPDIR/home"
                  export npm_config_cache="$TMPDIR/npm-cache"
                  npm install --omit=dev --ignore-scripts --legacy-peer-deps --no-audit --no-fund
                  mkdir -p $out
                  cp -R node_modules $out/node_modules
                  runHook postInstall
                '';

                outputHashAlgo = "sha256";
                outputHashMode = "recursive";
                outputHash = "sha256-UJ+sMdJFJ5GodKjuQVosKnIBXoMLWMmCg4RrbUCwW3Y=";
              };
            in
            prev.stdenv.mkDerivation {
              pname = "agentmemory";
              inherit version src;

              nativeBuildInputs = [
                prev.makeWrapper
                prev.nodejs
                prev.pkg-config
                prev.python3
              ];

              buildInputs = [ prev.vips ];

              dontConfigure = true;
              dontBuild = true;

              installPhase = ''
                runHook preInstall
                mkdir -p $out/lib/node_modules/@agentmemory/agentmemory
                cp -R . $out/lib/node_modules/@agentmemory/agentmemory
                cp -R ${nodeModules}/node_modules $out/lib/node_modules/@agentmemory/agentmemory/node_modules
                chmod -R u+w $out/lib/node_modules/@agentmemory/agentmemory/node_modules

                # @xenova/transformers is an optional dependency used by local
                # embeddings. npm's --ignore-scripts keeps the optional dependency
                # tree vendorable as a fixed-output dependency set, but leaves
                # sharp without its native addon. Build sharp here, in the normal
                # package derivation, where references to Nix-provided libvips are
                # allowed.
                export HOME="$TMPDIR/home"
                export npm_config_cache="$TMPDIR/npm-cache"
                export npm_config_build_from_source=true
                export npm_config_sharp_libvips_global=true
                export npm_config_nodedir=${prev.nodejs}
                npm --prefix $out/lib/node_modules/@agentmemory/agentmemory rebuild sharp --build-from-source

                makeWrapper ${prev.nodejs}/bin/node $out/bin/agentmemory \
                  --prefix PATH : ${prev.lib.makeBinPath [ final.iii-engine ]} \
                  --add-flags $out/lib/node_modules/@agentmemory/agentmemory/dist/cli.mjs
                runHook postInstall
              '';

              passthru = {
                inherit nodeModules;
                iii-engine = final.iii-engine;
              };

              meta = {
                description = "Persistent memory server for AI coding agents";
                homepage = "https://github.com/rohitg00/agentmemory";
                license = lib.licenses.asl20;
                mainProgram = "agentmemory";
                platforms = [ "x86_64-linux" ];
              };
            };

          # Primary FlakeHub nixpkgs still lags a few host-required package versions.
          # Pull narrow package overrides from nixpkgs-llama until FlakeHub catches up.
          llamaPackageSet = inputs.nixpkgs-llama.legacyPackages.${prev.stdenv.hostPlatform.system};
          bun = final.llamaPackageSet.bun.overrideAttrs (
            oldAttrs:
            let
              bunX86LinuxSrc = prev.fetchurl {
                url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.14/bun-linux-x64.zip";
                hash = "sha256-lR7iruhV8IWVruxiJSJqKY0/6oOj3NZGXAnLzN9+hI8=";
              };
            in
            {
              version = "1.3.14";
              src = bunX86LinuxSrc;
              passthru = oldAttrs.passthru // {
                sources = oldAttrs.passthru.sources // {
                  "x86_64-linux" = bunX86LinuxSrc;
                };
              };
            }
          );
          llama-cpp = final.llamaPackageSet.llama-cpp;

          llm-agents =
            let
              pinnedGitButlerPackages = inputs.llm-agents-gitbutler.packages.${final.stdenv.hostPlatform.system};
            in
            prev.llm-agents
            // {
              omp = prev.llm-agents.omp.overrideAttrs (
                oldAttrs:
                let
                  napiArch =
                    {
                      x86_64 = "x64";
                      aarch64 = "arm64";
                    }
                    .${final.stdenv.hostPlatform.parsed.cpu.name}
                      or (throw "Unsupported OMP native addon CPU: ${final.stdenv.hostPlatform.parsed.cpu.name}");
                  napiPlatform = "${final.stdenv.hostPlatform.parsed.kernel.name}-${napiArch}";
                in
                {
                  # The upstream package builds a Bun standalone executable. With Bun
                  # 1.3.14 that ELF segfaults in glibc's loader after Nix autoPatchelf,
                  # before OMP userland code runs. OMP is a Node/Bun CLI, so package it
                  # in the usual runner shape instead: build only the Rust native addon
                  # and generated assets, then run the TypeScript entrypoint with Bun.
                  autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];

                  patches = (oldAttrs.patches or [ ]) ++ [
                    ../packages/omp-auth-gateway-tool-call-id.patch
                    ../packages/omp-auth-gateway-cached-models.patch
                  ];

                  buildPhase = ''
                    runHook preBuild

                    export LD_LIBRARY_PATH="${lib.makeLibraryPath [ final.stdenv.cc.cc.lib ]}"
                    export LIBCLANG_PATH="${final.libclang.lib}/lib"

                    echo "Building Rust native addon..."
                    cargo build --release -p pi-natives --target ${final.stdenv.hostPlatform.rust.rustcTarget} --target-dir target

                    mkdir -p packages/natives/native
                    cp target/${final.stdenv.hostPlatform.rust.rustcTarget}/release/libpi_natives.so \
                      packages/natives/native/pi_natives.${napiPlatform}.node

                    napiBin="$(pwd)/node_modules/.bin/napi"
                    if [ -x "$napiBin" ]; then
                      "$napiBin" build \
                        --manifest-path crates/pi-natives/Cargo.toml \
                        --package-json-path packages/natives/package.json \
                        --platform \
                        --no-js \
                        --dts index.d.ts \
                        -o packages/natives/native \
                        --release \
                        || echo "napi CLI post-processing failed; using cargo output directly"
                    fi

                    if [ -f packages/natives/scripts/gen-enums.ts ] && \
                       [ -f packages/natives/native/index.d.ts ]; then
                      bun packages/natives/scripts/gen-enums.ts
                    fi

                    echo "Generating docs index..."
                    bun packages/coding-agent/scripts/generate-docs-index.ts

                    runHook postBuild
                  '';

                  installPhase = ''
                    runHook preInstall

                    mkdir -p $out/lib/omp/source $out/bin
                    cp -R package.json bun.lock node_modules packages $out/lib/omp/source/

                    makeWrapper ${final.bun}/bin/bun $out/bin/omp \
                      --add-flags "$out/lib/omp/source/packages/coding-agent/src/cli.ts" \
                      --set PI_SKIP_VERSION_CHECK 1 \
                      --prefix LD_LIBRARY_PATH : ${
                        lib.makeLibraryPath [
                          final.zlib
                          final.stdenv.cc.cc.lib
                        ]
                      }

                    runHook postInstall
                  '';
                }
              );
              but = pinnedGitButlerPackages.but;
            };
        })
      ];

      networking.hostName = host.name;
      networking.hostId = host.hostId;
      nix.settings.trusted-users = host.trustedUsers;
      system.stateVersion = host.stateVersion;
      users.mutableUsers = host.userManagement.mutableUsers;
      systemd.tmpfiles.rules =
        host.userManagement.tmpfilesRules
        ++ lib.optionals hindsightLlama.enable [
          "d /var/lib/hermes/models 0755 hermes hermes - -"
        ];
      home-manager.useGlobalPkgs = host.homeManager.useGlobalPkgs;
      home-manager.useUserPackages = host.homeManager.useUserPackages;

      time.timeZone = host.timeZone;
      i18n.defaultLocale = host.defaultLocale;
      console.keyMap = host.consoleKeyMap;

      networking.networkmanager.enable = true;
      networking.firewall.enable = false;

      services.power-profiles-daemon.enable = false;
      services.thermald.enable = true;
      services.printing.enable = true;
      services.xserver.videoDrivers = [ "modesetting" ];

      boot.initrd.availableKernelModules = host.hardware.initrdAvailableKernelModules;
      boot.initrd.kernelModules = host.hardware.initrdKernelModules;
      boot.kernelModules = host.hardware.kernelModules;
      boot.kernelParams = host.hardware.kernelParams;
      boot.kernel.sysctl = host.hardware.kernelSysctl;
      boot.zfs.forceImportRoot = host.hardware.zfsForceImportRoot;
      boot.extraModulePackages = hardwareExtraModulePackages;
      boot.loader.efi.canTouchEfiVariables = host.hardware.boot.efiCanTouchVariables;
      boot.loader.systemd-boot.enable = host.hardware.boot.systemdBootEnable;
      boot.loader.systemd-boot.extraInstallCommands = lib.mkIf host.hardware.boot.fallbackSync.enable ''
        ${pkgs.rsync}/bin/rsync -av --delete ${host.hardware.boot.fallbackSync.source} ${host.hardware.boot.fallbackSync.target}
      '';

      hardware.enableRedistributableFirmware = host.hardware.enableRedistributableFirmware;
      hardware.cpu.intel.updateMicrocode = lib.mkDefault (
        if host.hardware.cpu.intel.updateMicrocodeFromRedistributableFirmware then
          config.hardware.enableRedistributableFirmware
        else
          false
      );
      hardware.graphics = {
        enable = host.hardware.graphics.enable;
        extraPackages = hardwareGraphicsExtraPackages;
      };
      swapDevices = host.hardware.swapDevices;
      powerManagement.cpuFreqGovernor = lib.mkIf (
        host.hardware.cpuFreqGovernor != null
      ) host.hardware.cpuFreqGovernor;
      services.zfs.autoScrub.enable = host.hardware.zfsMaintenance.autoScrub;
      services.zfs.trim.enable = host.hardware.zfsMaintenance.trim;

      services.openssh.enable = true;
      services.openssh.hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];

      sops.defaultSopsFile = repoPath host.secrets.defaultSopsFile;
      sops.age.keyFile = host.secrets.ageKeyFile;
      sops.age.sshKeyPaths = host.secrets.ageSshKeyPaths;
      sops.secrets = lib.mapAttrs renderSecret host.secrets.bindings;

      system.activationScripts.hermes-soul-md = lib.mkIf host.platform.provisioning.soul.enable (
        lib.stringAfter host.platform.provisioning.soul.after ''
          soul_path=${config.services.hermes-agent.stateDir}/${host.platform.provisioning.soul.relativePath}
          soul_dir=$(dirname "$soul_path")
          # Create .hermes/ with hermes ownership before install so the service
          # user can write into the directory once it starts.
          if [ ! -d "$soul_dir" ]; then
            install -d \
              -o ${config.services.hermes-agent.user} \
              -g ${config.services.hermes-agent.group} \
              -m ${host.platform.provisioning.soul.directoryMode} \
              "$soul_dir"
          fi
          if [ ! -f "$soul_path" ]; then
            install \
              -o ${config.services.hermes-agent.user} \
              -g ${config.services.hermes-agent.group} \
              -m ${host.platform.provisioning.soul.fileMode} \
              ${config.sops.secrets.${host.platform.provisioning.soul.secretName}.path} "$soul_path"
          fi
        ''
      );

      system.activationScripts.hermes-github-auth = lib.mkIf host.platform.provisioning.githubAuth.enable (
        lib.stringAfter host.platform.provisioning.githubAuth.after ''
          state_dir=${config.services.hermes-agent.stateDir}
          creds_path=$state_dir/${host.platform.provisioning.githubAuth.gitCredentialsRelativePath}
          gh_config_dir=$state_dir/${host.platform.provisioning.githubAuth.ghConfigRelativeDir}
          gh_parent_dir=$(dirname "$gh_config_dir")
          gh_hosts_path=$gh_config_dir/hosts.yml
          gh_config_path=$gh_config_dir/config.yml
          token=$(grep "^${host.platform.provisioning.githubAuth.tokenVariable}=" ${
            config.sops.secrets.${host.platform.provisioning.githubAuth.secretName}.path
          } | cut -d= -f2-)
          # Strip surrounding double quotes using bash parameter expansion —
          # sed is not available in the activation script PATH.
          token=''${token#\"}
          token=''${token%\"}

          if [ -n "$token" ]; then
            # Create with correct ownership and mode atomically before writing
            # content — avoids a race where credentials are briefly readable by
            # another user.
            install -D -m 600 \
              -o ${config.services.hermes-agent.user} \
              -g ${config.services.hermes-agent.group} \
              /dev/null "$creds_path"
            printf 'https://${host.platform.provisioning.githubAuth.username}:%s@github.com\n' "$token" > "$creds_path"

            install -d \
              -o ${config.services.hermes-agent.user} \
              -g ${config.services.hermes-agent.group} \
              -m 0700 \
              "$gh_parent_dir"
            chmod u=rwx,go=,g-s "$gh_parent_dir"

            install -d \
              -o ${config.services.hermes-agent.user} \
              -g ${config.services.hermes-agent.group} \
              -m 0700 \
              "$gh_config_dir"
            chmod u=rwx,go=,g-s "$gh_config_dir"

            install -m 600 \
              -o ${config.services.hermes-agent.user} \
              -g ${config.services.hermes-agent.group} \
              /dev/null "$gh_hosts_path"
            printf '%s\n' \
              'github.com:' \
              "    oauth_token: $token" \
              '    user: ${host.platform.provisioning.githubAuth.username}' \
              '    git_protocol: https' \
              > "$gh_hosts_path"

            install -m 600 \
              -o ${config.services.hermes-agent.user} \
              -g ${config.services.hermes-agent.group} \
              /dev/null "$gh_config_path"
          else
            # Token removed from secret — revoke files so stale credentials
            # do not persist on disk.
            rm -f "$creds_path" "$gh_hosts_path" "$gh_config_path"
          fi

          # Smoke-test that gh can read its configured token without requiring
          # network access. This catches malformed hosts.yml during activation.
          if [ -f "$gh_hosts_path" ]; then
            HOME=$state_dir ${pkgs.gh}/bin/gh auth token >/dev/null
          fi
        ''
      );

      systemd.services.llama-server = lib.mkIf hindsightLlama.enable {
        description = "llama.cpp inference server (${hindsightLlamaModelName})";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          Type = "simple";
          User = "hermes";
          StateDirectory = "hermes";
          Restart = "on-failure";
          RestartSec = "5s";
          ExecStartPre = pkgs.writeShellScript "llama-server-precheck" ''
            if [ ! -f ${lib.escapeShellArg hindsightLlama.modelPath} ]; then
              echo "ERROR: model file not found at ${hindsightLlama.modelPath}"
              echo "Place the Gemma GGUF at services.hindsightMemory.llama.modelPath or override that option."
              exit 1
            fi
          '';
          ExecStart = lib.escapeShellArgs ([ "${pkgs.llama-cpp}/bin/llama-server" ] ++ hindsightLlamaArgs);
        };
      };

      # Keep the retired Hindsight provider disabled by default but render its
      # cleanup/config activation behavior from Den so stale interactive setup
      # cannot override the active AgentMemory backend.
      services.hindsightMemory = {
        enable = lib.mkDefault host.services.hindsightMemory.enable;
        llama.enable = lib.mkDefault host.services.hindsightMemory.llama.enable;
      };

      services.hermes-agent = lib.mkIf config.services.hindsightMemory.enable {
        settings.memory.provider = "hindsight";
        environment = {
          HINDSIGHT_MODE = hindsightProviderConfig.mode;
          HINDSIGHT_API_URL = hindsightProviderConfig.api_url;
          HINDSIGHT_BANK_ID = hindsightProviderConfig.bank_id;
          HINDSIGHT_BUDGET = hindsightProviderConfig.budget;
        };
      };

      systemd.services.hermes-agent = lib.mkIf config.services.hindsightMemory.enable {
        after = [ "hindsight-embed.service" ];
      };

      system.activationScripts.hermes-hindsight-config =
        lib.stringAfter host.services.hindsightMemory.activationAfter
          (
            if config.services.hindsightMemory.enable then
              ''
                install -d \
                  -o ${config.services.hermes-agent.user} \
                  -g ${config.services.hermes-agent.group} \
                  -m 0750 \
                  ${hermesHome}/hindsight
                install -m 0640 \
                  -o ${config.services.hermes-agent.user} \
                  -g ${config.services.hermes-agent.group} \
                  ${hindsightConfig} ${hermesHome}/hindsight/config.json
              ''
            else
              ''
                rm -f ${hermesHome}/hindsight/config.json
              ''
          );

      services.dbus.implementation = "dbus";
      security.sudo.wheelNeedsPassword = false;
      environment.systemPackages =
        (builtins.map packageByName host.systemPackages) ++ platformVirtualisationPackages;
      environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

      users.users = {
        root.openssh.authorizedKeys.keys = root.sshAuthorizedKeys;
        admin = {
          isNormalUser = admin.normalUser;
          inherit (admin)
            description
            home
            createHome
            homeMode
            ;
          extraGroups = admin.extraGroups ++ host.platform.virtualisation.rootEquivalentGroups;
          openssh.authorizedKeys.keys = admin.sshAuthorizedKeys;
        };
        hermes = {
          inherit (hermes) description;
          extraGroups = host.platform.virtualisation.rootEquivalentGroups;
          openssh.authorizedKeys.keys = hermes.sshAuthorizedKeys;
        };
        # NixOS has an implicit users.users.<name> option value for names that
        # appear elsewhere in the module graph. Keep the VM fixture inert and
        # assertion-safe on the production host; the VM smoke flips it on below.
        den-poc = {
          enable = false;
          isSystemUser = true;
          group = "nogroup";
        };
      }
      // lib.optionalAttrs config.den.fixtures.denPoc.enable {
        den-poc = {
          enable = true;
          isSystemUser = false;
          isNormalUser = denPoc.normalUser;
          inherit (denPoc) home createHome;
        };
      };

      home-manager.users = {
        admin = pkgs.lib.recursiveUpdate sharedUserConfig direnvConfig // {
          home = vitePlusHome // {
            stateVersion = "25.05";
            packages = adminHomePackages ++ vitePlusToolchain;
            sessionVariables = {
              XDG_DATA_HOME = "$HOME/.local/share";
              XDG_STATE_HOME = "$HOME/.local/state";
              XDG_CACHE_HOME = "$HOME/.cache";
              XDG_CONFIG_HOME = "$HOME/.config";
            };
          };
        };
        hermes = sharedUserConfig // {
          home = vitePlusHome // {
            stateVersion = "25.05";
            packages = vitePlusToolchain;
          };
        };
      }
      // lib.optionalAttrs config.den.fixtures.denPoc.enable {
        den-poc = {
          home.stateVersion = "25.05";
          home.packages = [ pkgs.glow ];
        };
      };

      virtualisation.docker = {
        enable = host.platform.virtualisation.docker.enable;
        storageDriver = lib.mkIf (
          host.platform.virtualisation.docker.storageDriver != null
        ) host.platform.virtualisation.docker.storageDriver;
        autoPrune = lib.mkIf (host.platform.virtualisation.docker.autoPruneDates != null) {
          enable = true;
          dates = host.platform.virtualisation.docker.autoPruneDates;
        };
      };

      virtualisation.libvirtd = {
        enable = host.platform.virtualisation.libvirt.enable;
        qemu.vhostUserPackages = lib.mkIf host.platform.virtualisation.libvirt.enable [ pkgs.virtiofsd ];
      };
    };
}
