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
      storageModules = [
        "den/hosts/nixos-hermes/storage/disk-config.nix"
      ];
      secretModules = [ ];
      platformModules = [ ];
      serviceModules = [
        "den/hosts/nixos-hermes/services/llama-server.nix"
        "den/hosts/nixos-hermes/services/hindsight-embed.nix"
        "den/hosts/nixos-hermes/services/hindsight-memory.nix"
        "den/hosts/nixos-hermes/services/agentmemory.nix"
        "den/hosts/nixos-hermes/services/netdata.nix"
        "den/hosts/nixos-hermes/services/omp-auth-gateway.nix"
        "den/hosts/nixos-hermes/services/hermes-agent/default.nix"
        "den/hosts/nixos-hermes/services/hermes-agent/plugins.nix"
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
      storage.diskoConfigPath = "den/hosts/nixos-hermes/storage/disk-config.nix";
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

      # VM-only fixture used to prove same-user mixed Den/native Home Manager
      # migration. It is not production inventory.
      users.den-poc = {
        normalUser = true;
        hasHomeManagerConfig = true;
        home = "/home/den-poc";
        createHome = true;
        classes = [ "homeManager" ];
      };
    };

  den.aspects.nixos-hermes.os =
    {
      lib,
      pkgs,
      modulesPath,
      config,
      inputs,
      nixpkgs-llama,
      llm-agents,
      llm-agents-gitbutler,
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
    in
    {
      imports = lib.optionals host.hardware.importNotDetected [
        (modulesPath + "/installer/scan/not-detected.nix")
      ];


        # Allow specific unfree packages needed by the system.
        nixpkgs.config.allowUnfreePredicate =
          pkg:
          builtins.elem (lib.getName pkg) host.nixpkgs.allowedUnfree;

        nixpkgs.overlays = [
          # llm-agents.nix provides claude-code, codex, omp, agent-browser, and many more.
          # Use the default overlay for the fast-moving main input so npm packages build
          # with llm-agents' own compatible nixpkgs; GitButler is overridden below from
          # a separate pinned input.
          llm-agents.overlays.default
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
            llamaPackageSet = nixpkgs-llama.legacyPackages.${prev.stdenv.hostPlatform.system};
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
                pinnedGitButlerPackages = llm-agents-gitbutler.packages.${final.stdenv.hostPlatform.system};
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
      systemd.tmpfiles.rules = host.userManagement.tmpfilesRules;
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

      services.dbus.implementation = "dbus";
      security.sudo.wheelNeedsPassword = false;
      environment.systemPackages =
        (builtins.map packageByName host.systemPackages) ++ platformVirtualisationPackages;
      environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

      users.users.root.openssh.authorizedKeys.keys = root.sshAuthorizedKeys;
      users.users.admin = {
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
      users.users.hermes = {
        inherit (hermes) description;
        extraGroups = host.platform.virtualisation.rootEquivalentGroups;
        openssh.authorizedKeys.keys = hermes.sshAuthorizedKeys;
      };
      users.users.den-poc = {
        isNormalUser = denPoc.normalUser;
        inherit (denPoc) home createHome;
      };

      home-manager.users.admin = pkgs.lib.recursiveUpdate sharedUserConfig direnvConfig // {
        home = vitePlusHome // {
          stateVersion = "25.05";
          packages =
            (with pkgs; [
              bat
              glow
              yazi
              inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp
            ])
            ++ vitePlusToolchain;
          sessionVariables = {
            XDG_DATA_HOME = "$HOME/.local/share";
            XDG_STATE_HOME = "$HOME/.local/state";
            XDG_CACHE_HOME = "$HOME/.cache";
            XDG_CONFIG_HOME = "$HOME/.config";
          };
        };
      };
      home-manager.users.hermes = sharedUserConfig // {
        home = vitePlusHome // {
          stateVersion = "25.05";
          packages = vitePlusToolchain;
        };
      };
      home-manager.users.den-poc = {
        home.stateVersion = "25.05";
        home.packages = [ pkgs.glow ];
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
