# repowise-nix

Standalone Nix/Linux packaging and workflow wrapper for [Repowise](https://github.com/repowise-dev/repowise).

This flake is intentionally separate from the `nixos-hermes` host modules. Package and wrapper changes can be built or run directly without rebuilding a NixOS host:

```bash
nix build ./packages/repowise-nix#repowise
nix build ./packages/repowise-nix#repowise-nix
nix run ./packages/repowise-nix -- index
```

## Commands

- `repowise` is the patched upstream CLI.
- `repowise-nix` is a portable wrapper that defaults to the current working tree and adds safe agent-oriented defaults.

```bash
repowise-nix status
repowise-nix index
repowise-nix generate --test-run
repowise-nix refresh --test-run
repowise-nix reindex
repowise-nix search "workspace task backend" --mode semantic --limit 5
repowise-nix dead-code
```

The wrapper passes through commands it does not special-case, so upstream commands such as `dead-code`, `health`, and `risk` stay available without reimplementing the CLI surface. Excludes are applied only to wrapper-managed indexing/generation commands where upstream accepts `--exclude`.

## Configuration

The wrapper has generic defaults and exposes repo preferences through environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `REPOWISE_REPO` | `$PWD` | Worktree to operate on. |
| `REPOWISE_EDITOR_SETUP` | `0` | Set to `1` to allow Repowise editor/MCP setup side effects. |
| `REPOWISE_EXTRA_EXCLUDES` | unset | Colon-separated extra `--exclude` globs. |
| `REPOWISE_PROVIDER` | `openai` | LLM provider for generation. |
| `REPOWISE_MODEL` | `gemini-3.1-flash-lite-preview` | LLM model for generation. |
| `REPOWISE_EMBEDDER` | `gemini` | Embedding provider. |
| `REPOWISE_OPENAI_API_KEY` | unset | Scoped OpenAI-compatible API key; mapped to `OPENAI_API_KEY` only inside the Repowise subprocess. |
| `REPOWISE_OPENAI_BASE_URL` | unset | Scoped OpenAI-compatible base URL; mapped to `OPENAI_BASE_URL` only inside the Repowise subprocess. |
| `REPOWISE_COVERAGE` | `0.20` | Generation coverage. |
| `REPOWISE_CONCURRENCY` | `4` | Generation concurrency. |

Examples:

```bash
REPOWISE_REPO=/path/to/repo repowise-nix index

REPOWISE_EXTRA_EXCLUDES='docs/spikes/repowise-nix/artifacts/**:vendor/**' \
  repowise-nix index

REPOWISE_EDITOR_SETUP=1 repowise-nix generate --test-run
```

## Supported Nix analysis patterns

The local Repowise patch is static-only. It does not run `nix` and does not try to evaluate arbitrary expressions. Supported Nix reachability patterns are intentionally boring:

- `imports = [ ./module.nix ../other.nix ];`
- `import ./file.nix`
- `callPackage ./package.nix { }` and selected `.callPackage` receivers
- directory fallbacks for `./foo` as `foo.nix`, `foo/default.nix`, then `foo/flake.nix`
- selected `evalModule` / `.lib.evalModule` path arguments such as `treefmt-nix.lib.evalModule pkgs ./treefmt.nix`
- local flake input URLs like `url = "path:./packages/tool"`, preferring nested `flake.nix`
- common flake/infrastructure roots such as `flake.nix`, `default.nix`, `treefmt.nix`, `packages`, `modules`, `hosts`, and `tests`

Unsupported dynamic expressions degrade conservatively: they should not create high-confidence deletion recommendations just because static parsing cannot prove the edge.

Patch organization stays source-level and rebaseable: `repowise-nix-language-support.patch` carries Nix parsing/resolver/dead-code behavior plus tests; `repowise-status-stale-schema-warning.patch` only carries stale local-index UX. No generated/minified/dist surgery is part of the durable patch path.

## Safety model

By default `repowise-nix` disables Repowise editor setup:

- exports `REPOWISE_DISABLE_EDITOR_SETUP=1`
- passes `--no-claude-md` for wrapper-managed `index`, `generate`, and `refresh` commands

That default keeps indexing/generation from silently creating `.mcp.json`, `.claude/CLAUDE.md`, or home-level Claude settings. Opt in explicitly with `REPOWISE_EDITOR_SETUP=1` when editor integration is the intended action.
