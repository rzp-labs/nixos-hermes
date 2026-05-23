# Repowise through repowise-nix

Repowise is the repo-orientation map for this flake. It is not an answer oracle and it is not a replacement for reading source. Use it to find the right files, ownership clusters, central modules, semantic matches, generated pages, and graph context before editing.

## Artifact shape

Repowise packaging is owned by the standalone local flake at `packages/repowise-nix/`, not by host-specific package glue. That is deliberate: package and wrapper changes can be built, run, and validated directly without rebuilding `nixos-hermes`.

```bash
nix build ./packages/repowise-nix#repowise
nix build ./packages/repowise-nix#repowise-nix
nix run ./packages/repowise-nix -- index
```

The NixOS host only installs the flake's package outputs into:

- `environment.systemPackages`
- `services.hermes-agent.extraPackages`

## Installed commands

The host installs two commands for both operators and the Hermes service:

- `repowise` — upstream CLI, packaged through Nix with the local Nix-language patch applied.
- `repowise-nix` — portable Nix/Linux wrapper with safe agent defaults.

## Wrapper commands

Run from the target worktree, or set `REPOWISE_REPO` explicitly:

```bash
repowise-nix status
repowise-nix index
repowise-nix generate --test-run
repowise-nix refresh --test-run  # alias for generate
repowise-nix reindex
repowise-nix search "hermes workspace task backend" --mode semantic --limit 5
repowise-nix dead-code
```

The wrapper defaults to `$PWD`, not a Hermes or NixOS host path. Override with:

```bash
REPOWISE_REPO=/path/to/repo repowise-nix status
```

## Defaults and repo preferences

`repowise-nix generate` / `repowise-nix refresh` use these defaults unless overridden:

```bash
REPOWISE_PROVIDER=openai
REPOWISE_MODEL=gemini-3.1-flash-lite-preview
REPOWISE_EMBEDDER=gemini
REPOWISE_COVERAGE=0.20
REPOWISE_CONCURRENCY=4
```

Repo-specific preferences must be environment options, not baked into the command name or hardcoded host paths. For this repo, use:

```bash
REPOWISE_EXTRA_EXCLUDES='docs/spikes/repowise-nix/artifacts/**' repowise-nix index
```

The OpenAI provider default matches Repowise's OpenAI-compatible SDK path. This host can route generation through CLIProxyAPI by setting `OPENAI_BASE_URL` and `OPENAI_API_KEY` in the runtime environment. Gemini embeddings remain a separate direct-provider boundary because CLIProxyAPI does not expose `/v1/embeddings` yet.

Do not commit keys. Use environment or sops-managed runtime files only.

## Index hygiene

For wrapper-managed `index`, `generate`, and `refresh`, the wrapper excludes generic transient paths and disables Repowise's editor setup layer by default (`REPOWISE_DISABLE_EDITOR_SETUP=1` plus `--no-claude-md`) so indexing stays a repo-orientation operation instead of silently rewriting editor, MCP, or Claude Code config:

```text
.repowise/**
.git/**
.direnv/**
```

Opt into editor setup only when that is the explicit task:

```bash
REPOWISE_EDITOR_SETUP=1 repowise-nix generate --test-run
```

## Validation

Standalone package/wrapper invariant:

```bash
nix build ./packages/repowise-nix#checks.x86_64-linux.repowise-nix-tooling --no-link --no-eval-cache -L
```

Host integration invariant:

```bash
nix build .#checks.x86_64-linux.repowise-nix-tooling --no-link --no-eval-cache -L
```

Runtime smoke without LLM credentials:

```bash
repowise-nix index
repowise-nix status
```

Runtime smoke with LLM/embedding credentials:

```bash
OPENAI_BASE_URL=http://10.0.0.102:8317/v1 \
OPENAI_API_KEY=... \
GEMINI_API_KEY=... \
REPOWISE_EXTRA_EXCLUDES='docs/spikes/repowise-nix/artifacts/**' \
repowise-nix generate --test-run

repowise-nix search "hermes workspace task backend" --mode semantic --limit 5
```

Again: keep keys out of commands that will be committed or pasted into reports.
