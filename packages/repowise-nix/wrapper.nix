{
  lib,
  nix,
  repowise,
  python3,
  writeShellApplication,
}:

writeShellApplication {
  name = "repowise-nix";
  runtimeInputs = [
    nix
    repowise
    python3
  ];
  text = ''
    set -euo pipefail

    # Repowise is packaged with its own Python closure. Hermes terminal sessions
    # often carry a PYTHONPATH for the Hermes sealed venv, and mixing Python
    # minor versions makes provider imports fail in misleading ways.
    unset PYTHONPATH

    repo="''${REPOWISE_REPO:-$PWD}"
    command="''${1:-status}"
    shift || true

    # Safe default for agent usage: do not let indexing/generation rewrite MCP,
    # Claude, or editor config. Set REPOWISE_EDITOR_SETUP=1 to opt back in.
    if [ "''${REPOWISE_EDITOR_SETUP:-0}" != "1" ]; then
      export REPOWISE_DISABLE_EDITOR_SETUP=1
      no_claude_md=(--no-claude-md)
    else
      no_claude_md=()
    fi

    common_excludes=(
      --exclude '.repowise/**'
      --exclude '.git/**'
      --exclude '.direnv/**'
    )

    if [ -n "''${REPOWISE_EXTRA_EXCLUDES:-}" ]; then
      IFS=':' read -r -a extra_excludes_arr <<< "$REPOWISE_EXTRA_EXCLUDES"
      for exclude in "''${extra_excludes_arr[@]}"; do
        if [ -n "$exclude" ]; then
          common_excludes+=(--exclude "$exclude")
        fi
      done
    fi

    # Repowise's OpenAI-compatible provider reads generic OPENAI_* env vars.
    # Keep host/Hermes credentials scoped, then adapt them only for this subprocess.
    if [ -n "''${REPOWISE_OPENAI_API_KEY:-}" ]; then
      export OPENAI_API_KEY="$REPOWISE_OPENAI_API_KEY"
    fi
    if [ -n "''${REPOWISE_OPENAI_BASE_URL:-}" ]; then
      export OPENAI_BASE_URL="$REPOWISE_OPENAI_BASE_URL"
    fi

    if [ ! -d "$repo" ]; then
      echo "repowise-nix: REPOWISE_REPO='$repo' does not exist" >&2
      exit 66
    fi

    cd "$repo"
    case "$command" in
      dead-code)
        export REPOWISE_NIX_REACHABILITY_SCRIPT=${./nix-reachability.py}
        exec python ${./nix_dead_code_cmd.py} "$@"
        ;;
      nix-reachability)
        exec python ${./nix-reachability.py} . "$@"
        ;;
      generate|refresh)
        exec repowise init . \
          --provider "''${REPOWISE_PROVIDER:-openai}" \
          --model "''${REPOWISE_MODEL:-gemini-3.1-flash-lite-preview}" \
          --embedder "''${REPOWISE_EMBEDDER:-gemini}" \
          --coverage "''${REPOWISE_COVERAGE:-0.20}" \
          --concurrency "''${REPOWISE_CONCURRENCY:-4}" \
          --yes \
          "''${no_claude_md[@]}" \
          "''${common_excludes[@]}" \
          "$@"
        ;;
      index)
        exec repowise init . \
          --index-only \
          "''${no_claude_md[@]}" \
          "''${common_excludes[@]}" \
          "$@"
        ;;
      reindex)
        exec repowise reindex --embedder "''${REPOWISE_EMBEDDER:-gemini}" "$@" .
        ;;
      search)
        if [ "$#" -eq 0 ]; then
          echo "usage: repowise-nix search QUERY [--mode fulltext|semantic|symbol] [--limit N]" >&2
          exit 64
        fi
        exec repowise search "$@" .
        ;;
      *)
        exec repowise "$command" "$@"
        ;;
    esac
  '';

  meta = {
    description = "Portable Nix/Linux Repowise wrapper with safe agent defaults";
    mainProgram = "repowise-nix";
    platforms = lib.platforms.linux;
  };
}
