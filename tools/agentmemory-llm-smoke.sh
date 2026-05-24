#!/usr/bin/env bash
# Live Agent Memory LLM behavior smoke.
# Proves more than "the flags are true": observation compression, enrichment/context
# injection, consolidation, and graph extraction reach live Agent Memory paths.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: tools/agentmemory-llm-smoke.sh [--api-url URL] [--timeout SECONDS] [--cliproxy-unit UNIT]

Runs live checks against the Agent Memory REST API. It does not print secrets.

Environment overrides:
  AGENTMEMORY_SMOKE_API_URL       default: http://127.0.0.1:3111
  AGENTMEMORY_SMOKE_TIMEOUT       default: 180
  AGENTMEMORY_SMOKE_PROJECT       default: current working directory
  AGENTMEMORY_HOOK_SCRIPT         optional explicit pre-tool-use hook path
  CLIPROXYAPI_JOURNAL_UNIT        optional systemd unit to scan for proxy request logs
USAGE
}

api_url="${AGENTMEMORY_SMOKE_API_URL:-http://127.0.0.1:3111}"
timeout_seconds="${AGENTMEMORY_SMOKE_TIMEOUT:-180}"
project="${AGENTMEMORY_SMOKE_PROJECT:-$(pwd)}"
cliproxy_unit="${CLIPROXYAPI_JOURNAL_UNIT:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-url)
      api_url="$2"
      shift 2
      ;;
    --timeout)
      timeout_seconds="$2"
      shift 2
      ;;
    --cliproxy-unit)
      cliproxy_unit="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

api_url="${api_url%/}"
export AGENTMEMORY_SMOKE_API_URL="$api_url"
export AGENTMEMORY_SMOKE_TIMEOUT="$timeout_seconds"
export AGENTMEMORY_SMOKE_PROJECT="$project"
export CLIPROXYAPI_JOURNAL_UNIT="$cliproxy_unit"
AGENTMEMORY_SMOKE_STARTED_AT="$(date --iso-8601=seconds)"
export AGENTMEMORY_SMOKE_STARTED_AT

hook_script="${AGENTMEMORY_HOOK_SCRIPT:-}"
if [[ -z "$hook_script" && -f flake.nix ]] && command -v nix >/dev/null 2>&1; then
  package_path="$(nix eval --raw .#nixosConfigurations.nixos-hermes.config.services.agentmemory.package 2>/dev/null || true)"
  candidate="$package_path/lib/node_modules/@agentmemory/agentmemory/dist/hooks/pre-tool-use.mjs"
  if [[ -n "$package_path" && -r "$candidate" ]]; then
    hook_script="$candidate"
  fi
fi
export AGENTMEMORY_HOOK_SCRIPT="$hook_script"

python3 - <<'PY'
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

api_url = os.environ["AGENTMEMORY_SMOKE_API_URL"].rstrip("/")
timeout = int(os.environ["AGENTMEMORY_SMOKE_TIMEOUT"])
project = os.environ["AGENTMEMORY_SMOKE_PROJECT"]
hook_script = os.environ.get("AGENTMEMORY_HOOK_SCRIPT") or ""
cliproxy_unit = os.environ.get("CLIPROXYAPI_JOURNAL_UNIT") or ""
started_at = os.environ["AGENTMEMORY_SMOKE_STARTED_AT"]

stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
marker = f"agentmemory-smoke-{stamp}"
session_id = f"{marker}-session"
file_path = os.path.join(project, "hosts/hermes/agentmemory.nix")


def request(method, path, payload=None, timeout_override=None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{api_url}{path}",
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout_override or min(timeout, 120)) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            if not body:
                return {}
            try:
                return json.loads(body)
            except json.JSONDecodeError as exc:
                raise SystemExit(f"FAIL: invalid JSON from {path}: {body[:1000]}") from exc
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"FAIL: HTTP {exc.code} from {path}: {body[:2000]}") from exc
    except urllib.error.URLError as exc:
        raise SystemExit(f"FAIL: connection error to {api_url}{path}: {exc.reason}") from exc


def contains_disabled(obj):
    if isinstance(obj, dict):
        status = obj.get("status")
        if isinstance(status, str) and status.lower() in {"disabled", "skipped"}:
            return True
        if obj.get("enabled") is False or obj.get("disabled") is True:
            return True
        return any(contains_disabled(value) for value in obj.values())
    if isinstance(obj, list):
        return any(contains_disabled(value) for value in obj)
    return isinstance(obj, str) and obj.lower() in {"disabled", "skipped"}


def wait_for_search():
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        last = request("POST", "/agentmemory/search", {"query": marker, "limit": 5})
        if marker in json.dumps(last):
            return last
        time.sleep(3)
    raise SystemExit(f"FAIL: marker was not searchable before timeout; last={json.dumps(last)[:2000]}")

def session_by_id(target_session_id):
    sessions_response = request("GET", "/agentmemory/sessions")
    sessions = sessions_response.get("sessions", []) if isinstance(sessions_response, dict) else []
    return next((s for s in sessions if s.get("id") == target_session_id), None)


health = request("GET", "/agentmemory/health")
livez = request("GET", "/agentmemory/livez")
if isinstance(health, dict) and health.get("status") not in (None, "healthy", "ok"):
    raise SystemExit(f"FAIL: unhealthy Agent Memory API: {health}")

observation_id = ""
search = {}
enrich = {}
hook_output = ""
graph = {}
graph_stats = {}
consolidate = {}
session_end = {}

try:
    request("POST", "/agentmemory/session/start", {
        "sessionId": session_id,
        "project": project,
        "cwd": project,
    })

    observe_payload = {
        "hookType": "post_tool_use",
        "sessionId": session_id,
        "project": project,
        "cwd": project,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "data": {
            "tool_name": "Read",
            "tool_input": {"file_path": file_path},
            "tool_output": (
                f"{marker} proves Agent Memory auto-compression via CLIProxyAPI for ONE-92. "
                "The observed relation is: ONE-92 uses CLIProxyAPI model gpt-5.4-mini. "
                f"Relevant file: {file_path}."
            ),
        },
    }
    observe = request("POST", "/agentmemory/observe", observe_payload, timeout_override=min(timeout, 180))
    observation_id = observe.get("observationId") or observe.get("id")
    if not observation_id:
        raise SystemExit(f"FAIL: observe did not return an observation id: {observe}")

    search = wait_for_search()

    enrich = request("POST", "/agentmemory/enrich", {
        "sessionId": session_id,
        "files": [file_path],
        "terms": [marker, "ONE-92", "CLIProxyAPI"],
        "toolName": "Read",
    })
    if marker not in json.dumps(enrich) and "agentmemory-relevant-context" not in json.dumps(enrich):
        raise SystemExit(f"FAIL: enrich did not return injected/relevant context for marker: {json.dumps(enrich)[:2000]}")

    if hook_script:
        hook_input = json.dumps({
            "session_id": session_id,
            "tool_name": "Read",
            "tool_input": {"file_path": file_path},
        })
        env = os.environ.copy()
        env.update({
            "AGENTMEMORY_URL": api_url,
            "AGENTMEMORY_INJECT_CONTEXT": "true",
        })
        try:
            proc = subprocess.run(
                ["node", hook_script],
                input=hook_input,
                text=True,
                capture_output=True,
                timeout=10,
                env=env,
                check=False,
            )
            hook_output = proc.stdout.strip()
            if proc.returncode != 0:
                raise SystemExit(f"FAIL: pre-tool hook exited {proc.returncode}: {proc.stderr[:1000]}")
            if marker not in hook_output and "agentmemory-relevant-context" not in hook_output:
                raise SystemExit(f"FAIL: pre-tool hook ran but did not inject expected context: stdout={hook_output[:1000]!r}")
        except FileNotFoundError as exc:
            raise SystemExit("FAIL: node is required to exercise the Agent Memory pre-tool hook") from exc

    compressed_observation = {
        "id": observation_id,
        "sessionId": session_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "title": f"{marker} CLIProxyAPI relation",
        "narrative": f"{marker} belongs_to ONE-92 and uses CLIProxyAPI model gpt-5.4-mini for Agent Memory LLM behavior.",
        "concepts": [marker, "ONE-92", "CLIProxyAPI", "gpt-5.4-mini"],
        "files": [file_path],
        "type": "fact",
        "importance": 0.8,
    }

    graph = request("POST", "/agentmemory/graph/extract", {"observations": [compressed_observation]}, timeout_override=min(timeout, 180))
    if contains_disabled(graph):
        raise SystemExit(f"FAIL: graph extraction appears disabled/skipped: {graph}")
    if graph.get("success") is False:
        raise SystemExit(f"FAIL: graph extraction reached path but failed: {graph}")

    graph_stats = request("GET", "/agentmemory/graph/stats")

    consolidate = request("POST", "/agentmemory/consolidate-pipeline", {
        "sessionId": session_id,
        "project": project,
    }, timeout_override=min(timeout, 180))
    if contains_disabled(consolidate):
        raise SystemExit(f"FAIL: consolidation appears disabled/skipped: {consolidate}")
    if isinstance(consolidate, dict) and consolidate.get("success") is False:
        # A concrete data/provider error is useful evidence, but this live smoke is a gate,
        # so fail loudly instead of pretending a configured feature is healthy.
        raise SystemExit(f"FAIL: consolidation reached enabled path but failed: {consolidate}")
finally:
    # This script creates a throwaway diagnostic Agent Memory session. Always close
    # it, even when an intermediate feature check fails, so repeated validation
    # runs do not inflate the live active-session inventory before Docker A/B work.
    try:
        session_end = request("POST", "/agentmemory/session/end", {"sessionId": session_id})
    except SystemExit as exc:
        print(f"WARN: failed to close smoke session {session_id}: {exc}", file=sys.stderr)
    except Exception as exc:
        print(f"WARN: failed to close smoke session {session_id}: {exc}", file=sys.stderr)

closed_session = session_by_id(session_id)
if not closed_session or closed_session.get("status") != "completed" or not closed_session.get("endedAt"):
    raise SystemExit(f"FAIL: smoke session was not closed after validation: {closed_session}")

journal_excerpt = ""
if cliproxy_unit:
    try:
        proc = subprocess.run(
            ["journalctl", "-u", cliproxy_unit, "--since", started_at, "--no-pager"],
            text=True,
            capture_output=True,
            timeout=10,
            check=False,
        )
        journal_excerpt = proc.stdout[-4000:]
    except Exception:
        journal_excerpt = ""

print("Agent Memory LLM smoke: PASS")
print(f"- api_url: {api_url}")
print(f"- health: {json.dumps(health, sort_keys=True)[:500]}")
print(f"- livez: {json.dumps(livez, sort_keys=True)[:500]}")
print(f"- marker: {marker}")
print(f"- session_id: {session_id}")
print(f"- session_closed: {closed_session.get('status') == 'completed' and bool(closed_session.get('endedAt'))}")
print(f"- session_end_result: {json.dumps(session_end, sort_keys=True)[:500]}")
print(f"- observation_id: {observation_id}")
print(f"- search_results_seen: {marker in json.dumps(search)}")
print(f"- enrich_context_chars: {len(json.dumps(enrich))}")
print(f"- pre_tool_hook: {'exercised' if hook_script else 'not-found; direct /enrich exercised'}")
if hook_output:
    print(f"- hook_output_chars: {len(hook_output)}")
print(f"- graph_result: {json.dumps(graph, sort_keys=True)[:800]}")
print(f"- graph_stats: {json.dumps(graph_stats, sort_keys=True)[:800]}")
print(f"- consolidate_result: {json.dumps(consolidate, sort_keys=True)[:1000]}")
if cliproxy_unit:
    lowered = journal_excerpt.lower()
    print(f"- cliproxy_journal_unit: {cliproxy_unit}")
    print(f"- cliproxy_journal_mentions_chat_completions: {'chat/completions' in lowered}")
    print(f"- cliproxy_journal_mentions_model: {'gpt-5.4-mini' in lowered}")
PY
