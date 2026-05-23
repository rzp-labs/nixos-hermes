# Repowise on nixos-hermes

Repowise is the repo-orientation map for this flake. It is not an answer oracle and it is not a replacement for reading source. Use it to find the right files, ownership clusters, central modules, generated wiki pages, semantic matches, and graph context before editing.

## Installed commands

The host installs two commands for both operators and the Hermes service:

- `repowise` — upstream CLI, packaged through Nix with the local Nix-language patch applied.
- `repowise-nixos-hermes` — opinionated wrapper for this repo.

The package is defined in `modules/packages.nix` and is wired into both:

- `environment.systemPackages`
- `services.hermes-agent.extraPackages`

## Wrapper commands

Run from anywhere:

```bash
repowise-nixos-hermes status
repowise-nixos-hermes index
repowise-nixos-hermes generate --test-run
repowise-nixos-hermes refresh --test-run  # alias for generate
repowise-nixos-hermes reindex
repowise-nixos-hermes search "hermes workspace task backend" --mode semantic --limit 5
```

By default the wrapper targets `/var/lib/hermes/workspace/nixos-hermes`. Override with:

```bash
REPOWISE_REPO=/path/to/repo repowise-nixos-hermes status
```

## Defaults

`repowise-nixos-hermes generate` / `repowise-nixos-hermes refresh` use these defaults unless overridden:

```bash
REPOWISE_PROVIDER=openai
REPOWISE_MODEL=gemini-3.1-flash-lite-preview
REPOWISE_EMBEDDER=gemini
REPOWISE_COVERAGE=0.20
REPOWISE_CONCURRENCY=4
```

The OpenAI provider default is intentional: Repowise uses the OpenAI SDK, and this host routes generation through CLIProxyAPI by setting `OPENAI_BASE_URL` and `OPENAI_API_KEY` in the runtime environment. Gemini embeddings remain a separate direct-provider boundary because CLIProxyAPI does not expose `/v1/embeddings` yet.

Do not commit keys. Use environment or sops-managed runtime files only.

## Index hygiene

The wrapper always excludes transient spike artifacts and disables Repowise's editor setup layer (`REPOWISE_DISABLE_EDITOR_SETUP=1` plus `--no-claude-md`) so indexing stays a repo-orientation operation instead of silently rewriting editor, MCP, or Claude Code config:

```text
docs/spikes/repowise-nix/artifacts/**
.repowise/**
.git/**
.direnv/**
```

This prevents Repowise from spending coverage documenting its own proof logs instead of the actual host configuration.

## Validation

Nix-level invariant:

```bash
nix build .#checks.x86_64-linux.repowise-agent-tooling --no-link --no-eval-cache -L
```

Runtime smoke without LLM credentials:

```bash
repowise-nixos-hermes index
repowise-nixos-hermes status
```

Runtime smoke with LLM/embedding credentials:

```bash
OPENAI_BASE_URL=http://10.0.0.102:8317/v1 \
OPENAI_API_KEY=... \
GEMINI_API_KEY=... \
repowise-nixos-hermes generate --test-run

repowise-nixos-hermes search "hermes workspace task backend" --mode semantic --limit 5
```

Again: keep keys out of commands that will be committed or pasted into reports.
