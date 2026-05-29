#!/usr/bin/env python3
"""Repowise dead-code wrapper with native Nix reachability evidence.

For Nix flakes, this treats `nix-reachability.py` as the authority for Nix file
reachability. If evaluator evidence cannot be collected, analysis fails hard
instead of falling back to heuristic static suppression.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def _run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def _strip_format_args(args: list[str]) -> tuple[list[str], str]:
    cleaned: list[str] = []
    requested_format = "table"
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--format" and i + 1 < len(args):
            requested_format = args[i + 1]
            i += 2
            continue
        if arg.startswith("--format="):
            requested_format = arg.split("=", 1)[1]
            i += 1
            continue
        cleaned.append(arg)
        i += 1
    return cleaned, requested_format


def _is_wrapper_reachable(finding: dict) -> bool:
    return finding.get("file_path") in {
        "packages/repowise-nix/native-dead-code.py",
        "packages/repowise-nix/nix-reachability.py",
    }


def _print_table(findings: list[dict]) -> None:
    print(f"Dead Code ({len(findings)} findings)")
    for finding in findings:
        name = finding.get("symbol_name") or finding.get("file_path")
        print(
            f"- {finding.get('kind')} {name} "
            f"confidence={finding.get('confidence')} safe={finding.get('safe_to_delete')} "
            f"reason={finding.get('reason')}"
        )


def main() -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--nixos-config", action="append", default=[])
    known, dead_code_args = parser.parse_known_args()

    repo = Path.cwd()
    filtered_args, requested_format = _strip_format_args(dead_code_args)

    nix_reachable: set[str] = set()
    if (repo / "flake.nix").exists():
        reachability_script = os.environ.get("REPOWISE_NIX_REACHABILITY_SCRIPT")
        if not reachability_script:
            sys.stderr.write("repowise-nix dead-code: REPOWISE_NIX_REACHABILITY_SCRIPT is not set.\n")
            return 1
        reachability_cmd = [sys.executable, reachability_script, "."]
        for config in known.nixos_config:
            reachability_cmd.extend(["--nixos-config", config])
        reachability = _run(reachability_cmd, repo)
        if reachability.returncode != 0:
            sys.stderr.write("repowise-nix dead-code: could not evaluate this flake's Nix reachability.\n")
            sys.stderr.write("Fix the Nix evaluation error below, then rerun dead-code analysis.\n")
            sys.stderr.write("No dead-code report was produced because Nix files cannot be classified safely without evaluator evidence.\n\n")
            sys.stderr.write(reachability.stderr or reachability.stdout)
            return reachability.returncode or 1
        nix_reachable = set(json.loads(reachability.stdout).get("files", []))

    dead = _run(["repowise", "dead-code", *filtered_args, "--format", "json"], repo)
    if dead.returncode != 0:
        sys.stderr.write(dead.stderr or dead.stdout)
        return dead.returncode

    lines = dead.stdout.splitlines()
    json_start = next((idx for idx, line in enumerate(lines) if line.lstrip().startswith("[")), None)
    if json_start is None:
        sys.stderr.write("repowise-nix dead-code: repowise did not emit JSON findings.\n")
        sys.stderr.write(dead.stdout)
        sys.stderr.write(dead.stderr)
        return 1
    findings = json.loads("\n".join(lines[json_start:]))
    if nix_reachable:
        findings = [
            finding
            for finding in findings
            if finding.get("file_path") not in nix_reachable and not _is_wrapper_reachable(finding)
        ]

    if requested_format == "json":
        print(json.dumps(findings, indent=2))
    elif requested_format == "md":
        print("# Dead Code Report\n")
        print(f"**Total findings:** {len(findings)}\n")
        for finding in findings:
            name = finding.get("symbol_name") or finding.get("file_path")
            print(f"- [{finding.get('kind')}] `{name}` — {finding.get('reason')}")
    else:
        _print_table(findings)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
