{
  lib,
  repowise,
  writeShellApplication,
}:

writeShellApplication {
  name = "repowise-nix";
  runtimeInputs = [ repowise ];
  text = ''
    set -euo pipefail

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
      set -f
      old_ifs="$IFS"
      IFS=':'
      for exclude in $REPOWISE_EXTRA_EXCLUDES; do
        if [ -n "$exclude" ]; then
          common_excludes+=(--exclude "$exclude")
        fi
      done
      IFS="$old_ifs"
      set +f
    fi

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
        exec repowise reindex --embedder "''${REPOWISE_EMBEDDER:-gemini}" "$repo" "$@"
        ;;
      search)
        if [ "$#" -eq 0 ]; then
          echo "usage: repowise-nix search QUERY [--mode fulltext|semantic|symbol] [--limit N]" >&2
          exit 64
        fi
        exec repowise search "$@" "$repo"
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
