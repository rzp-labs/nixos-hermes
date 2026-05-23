{
  pkgs,
  lib,
  inputs,
  nixpkgs-llama,
  llm-agents,
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
  opusCtypesShim = pkgs.writeTextDir "sitecustomize.py" ''
    import ctypes.util as _cu
    from pathlib import Path as _Path

    _OPUS_PATH = "${pkgs.libopus}/lib/libopus.so.0"
    _HERMES_LOCALES = _Path("${hermesLocales}")
    _orig = _cu.find_library

    def find_library(name, *args, **kwargs):
        if name == "opus":
            return _OPUS_PATH
        return _orig(name, *args, **kwargs)

    _cu.find_library = find_library

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
    # Uses shared-nixpkgs overlay so packages build against our pkgs (not blueprint thunks).
    llm-agents.overlays.shared-nixpkgs
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

      repowise =
        let
          py = prev.python313Packages;
          grammars = py.tree-sitter-grammars;
        in
        py.buildPythonApplication {
          pname = "repowise";
          version = "0.10.0-nixos-hermes";

          src = prev.fetchFromGitHub {
            owner = "repowise-dev";
            repo = "repowise";
            rev = "8d1d1875bb45213f26d55f1cb687a5d8628b3efb";
            hash = "sha256-nq2ZYqJMihPc5maGx+c5WgzzLFiOzfQsku+fDqID8L8=";
          };

          patches = [ ./patches/repowise-nix-language-support.patch ];

          pyproject = true;
          build-system = [ py.setuptools ];

          nativeBuildInputs = [ py.pythonRelaxDepsHook ];
          pythonRelaxDeps = [
            "tree-sitter-kotlin"
            "tree-sitter-luau"
            "tree-sitter-nix"
            "tree-sitter-swift"
            "litellm"
            "structlog"
            "rich"
            "watchdog"
          ];
          # The host nixpkgs does not currently package tree-sitter-swift or
          # tree-sitter-luau for Python 3.13. Repowise loads grammars lazily;
          # the nixos-hermes production path needs Nix/Python/TS/etc., not
          # Swift/Luau parsing. Keep import checks below as the real runtime
          # gate instead of failing the whole package on unused optional grammars.
          dontCheckRuntimeDeps = true;

          dependencies = with py; [
            httpx
            tree-sitter
            grammars.tree-sitter-python
            grammars.tree-sitter-typescript
            grammars.tree-sitter-javascript
            grammars.tree-sitter-go
            grammars.tree-sitter-rust
            grammars.tree-sitter-java
            grammars.tree-sitter-cpp
            grammars.tree-sitter-kotlin
            grammars.tree-sitter-ruby
            grammars.tree-sitter-c-sharp
            grammars.tree-sitter-scala
            grammars.tree-sitter-php
            grammars.tree-sitter-nix
            networkx
            scipy
            jinja2
            pathspec
            structlog
            sqlalchemy
            aiosqlite
            alembic
            pydantic
            tenacity
            gitpython
            pyyaml
            lancedb
            click
            rich
            watchdog
            fastapi
            uvicorn
            mcp
            apscheduler
            cryptography
            anthropic
            openai
            google-genai
            litellm
          ];

          doCheck = false;
          pythonImportsCheck = [
            "repowise.core"
            "repowise.cli.main"
            "repowise.server.app"
          ];

          meta = {
            description = "Codebase intelligence and wiki generator with local Nix support";
            homepage = "https://github.com/repowise-dev/repowise";
            license = lib.licenses.agpl3Only;
            mainProgram = "repowise";
            platforms = lib.platforms.linux;
          };
        };

      repowise-nixos-hermes = prev.writeShellApplication {
        name = "repowise-nixos-hermes";
        runtimeInputs = [ final.repowise ];
        text = ''
          set -euo pipefail

          repo="''${REPOWISE_REPO:-/var/lib/hermes/workspace/nixos-hermes}"
          command="''${1:-status}"
          shift || true

          export REPOWISE_DISABLE_EDITOR_SETUP=1

          common_excludes=(
            --exclude 'docs/spikes/repowise-nix/artifacts/**'
            --exclude '.repowise/**'
            --exclude '.git/**'
            --exclude '.direnv/**'
          )

          cd "$repo"
          case "$command" in
            generate|refresh)
              exec repowise init . \
                --provider "''${REPOWISE_PROVIDER:-openai}" \
                --model "''${REPOWISE_MODEL:-gemini-3.1-flash-lite-preview}" \
                --embedder "''${REPOWISE_EMBEDDER:-gemini}" \
                --coverage "''${REPOWISE_COVERAGE:-0.20}" \
                --concurrency "''${REPOWISE_CONCURRENCY:-4}" \
                --yes \
                --no-claude-md \
                "''${common_excludes[@]}" \
                "$@"
              ;;
            index)
              exec repowise init . \
                --index-only \
                --no-claude-md \
                "''${common_excludes[@]}" \
                "$@"
              ;;
            reindex)
              exec repowise reindex --embedder "''${REPOWISE_EMBEDDER:-gemini}" "$repo" "$@"
              ;;
            search)
              if [ "$#" -eq 0 ]; then
                echo "usage: repowise-nixos-hermes search QUERY [--mode fulltext|semantic|symbol] [--limit N]" >&2
                exit 64
              fi
              exec repowise search "$@" "$repo"
              ;;
            *)
              exec repowise "$command" "$@"
              ;;
          esac
        '';
      };

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
        prev.stdenvNoCC.mkDerivation {
          pname = "agentmemory";
          inherit version src;

          nativeBuildInputs = [ prev.makeWrapper ];

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall
            mkdir -p $out/lib/node_modules/@agentmemory/agentmemory
            cp -R . $out/lib/node_modules/@agentmemory/agentmemory
            ln -s ${nodeModules}/node_modules $out/lib/node_modules/@agentmemory/agentmemory/node_modules
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

      llm-agents = prev.llm-agents // {
        omp = prev.llm-agents.omp.overrideAttrs (
          _oldAttrs:
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
        but = prev.llm-agents.but.overrideAttrs (
          oldAttrs:
          let
            patchButSource = ''
              ${pkgs.python3}/bin/python3 - <<'PY'
              import tomllib
              from pathlib import Path

              cargo_toml = Path("crates/gitbutler-git/Cargo.toml")
              cargo_toml_text = cargo_toml.read_text()
              def find_file_id_dependencies(value):
                  if isinstance(value, dict):
                      if "file-id" in value:
                          yield value["file-id"]
                      for child in value.values():
                          yield from find_file_id_dependencies(child)

              file_id_dependencies = list(find_file_id_dependencies(tomllib.loads(cargo_toml_text)))
              if file_id_dependencies != [
                  {
                      "git": "https://github.com/notify-rs/notify",
                      "rev": "978fe719b066a8ce76b9a9d346546b1569eecfb6",
                      "version": "0.2.3",
                  }
              ]:
                  raise RuntimeError(f"unexpected file-id dependencies: {file_id_dependencies!r}")

              lines = cargo_toml_text.splitlines(keepends=True)
              replacement_count = 0
              for index, line in enumerate(lines):
                  if line.lstrip().startswith("file-id ="):
                      if replacement_count:
                          raise RuntimeError("found multiple file-id dependency lines")
                      indent = line[: len(line) - len(line.lstrip())]
                      newline = "\n" if line.endswith("\n") else ""
                      lines[index] = f'{indent}file-id = "0.2.3"{newline}'
                      replacement_count += 1

              cargo_toml_text = "".join(lines)
              if replacement_count != 1 or "https://github.com/notify-rs/notify" in cargo_toml_text:
                  raise RuntimeError("failed to normalize file-id dependency in Cargo.toml")
              cargo_toml.write_text(cargo_toml_text)

              workspace_toml = Path("Cargo.toml")
              workspace_toml_text = workspace_toml.read_text()
              old_gix_dependency = (
                  'gix = { version = "0.83.0", git = "https://github.com/GitoxideLabs/gitoxide", '
                  'rev = "575113dfb10b3ba12eb57f57a81b241e773968bd", default-features = false, features = ['
              )
              new_gix_dependency = 'gix = { version = "0.83.0", default-features = false, features = ['
              if workspace_toml_text.count(old_gix_dependency) != 1:
                  raise RuntimeError("unexpected workspace gix dependency")
              workspace_toml.write_text(workspace_toml_text.replace(old_gix_dependency, new_gix_dependency))

              lock = Path("Cargo.lock")
              text = lock.read_text()
              blocks = text.split("[[package]]\n")
              registry_sources = {}
              package_sources = []
              for block in blocks[1:]:
                  fields = {}
                  for line in block.splitlines():
                      if line.startswith(('name = ', 'version = ', 'source = ')):
                          key, value = line.split(' = ', 1)
                          fields[key] = value.strip('"')
                  name = fields.get('name')
                  version = fields.get('version')
                  source = fields.get('source')
                  if name and version and source:
                      package_sources.append((name, version, source, block))
                      if source.startswith('registry+'):
                          registry_sources[(name, version)] = source

              git_sources_to_normalize = {
                  (name, version, source): registry_sources[(name, version)]
                  for name, version, source, _block in package_sources
                  if source.startswith('git+') and (name, version) in registry_sources
              }

              dependency_replacements = 0
              for name, version, git_source in git_sources_to_normalize:
                  registry_source = registry_sources[(name, version)]
                  dependency_git_source = git_source.split('#', 1)[0]
                  old_dependency = f'"{name} {version} ({dependency_git_source})"'
                  new_dependency = f'"{name} {version} ({registry_source})"'
                  count = text.count(old_dependency)
                  if count:
                      text = text.replace(old_dependency, new_dependency)
                      dependency_replacements += count

              blocks = text.split("[[package]]\n")
              kept = [blocks[0]]
              removed_blocks = 0
              for block in blocks[1:]:
                  fields = {}
                  for line in block.splitlines():
                      if line.startswith(('name = ', 'version = ', 'source = ')):
                          key, value = line.split(' = ', 1)
                          fields[key] = value.strip('"')
                  identity = (fields.get('name'), fields.get('version'), fields.get('source'))
                  if identity in git_sources_to_normalize:
                      removed_blocks += 1
                      continue
                  kept.append('[[package]]\n' + block)

              if removed_blocks != len(git_sources_to_normalize):
                  raise RuntimeError(
                      f"removed {removed_blocks} git package blocks, expected {len(git_sources_to_normalize)}"
                  )
              if dependency_replacements == 0:
                  raise RuntimeError("no dependency source annotations normalized")

              lock.write_text("".join(kept))
              PY
            '';
            patchedSrc = pkgs.runCommand "gitbutler-${oldAttrs.version}-but-patched-source" { } ''
              cp -R ${oldAttrs.src} "$out"
              chmod -R u+w "$out"
              cd "$out"
              ${patchButSource}
            '';
          in
          {
            # GitButler's lockfile contains git-sourced crates that have the same
            # name/version as crates.io entries in the same workspace (`file-id`,
            # `gix-trace`). nixpkgs' fetch-cargo-vendor cannot vendor both
            # sources under one `<name>-<version>` directory, so normalize these
            # duplicate git entries to their crates.io source before vendoring
            # instead of removing the package from the system.
            src = patchedSrc;
            cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
              src = patchedSrc;
              name = "${oldAttrs.pname}-${oldAttrs.version}-vendor";
              hash = "sha256-Pz+LAc7jM1JCoA+73FC4C+aEQdpYSfuy7t0/O1RHH9E=";
            };
          }
        );
      };
    })
  ];
}
