{
  pkgs,
  lib,
  inputs,
  nixpkgs-llama,
  llm-agents,
  llm-agents-gitbutler,
  ...
}:

# Local package overrides — packages not yet available in the pinned nixpkgs channel.
# Also owns NixOS packaging workarounds that are packaging concerns, not service config.
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
  # Hermes 0.15.0's pyproject still includes only `hermes_cli`, not
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
in
{
  # Allow specific unfree packages needed by the system.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "but"
    ];

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

              patches = (oldAttrs.patches or [ ]) ++ [ ../packages/omp-auth-gateway-tool-call-id.patch ];

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
}
