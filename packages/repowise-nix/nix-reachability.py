#!/usr/bin/env python3
"""Collect Nix-native reachability evidence for a flake repository.

This is deliberately an evaluator adapter, not a syntax parser. It asks Nix
where evaluated flake outputs and NixOS option definitions came from, then
projects store-source paths back to paths relative to the working tree.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


def _run_json(repo: Path, expr: str, timeout: int) -> Any:
    proc = subprocess.run(
        [
            "nix",
            "--extra-experimental-features",
            "nix-command flakes",
            "eval",
            "--impure",
            "--json",
            "--expr",
            expr,
        ],
        cwd=repo,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip())
    return json.loads(proc.stdout)


def _store_source_mapping(repo: Path, timeout: int) -> str:
    expr = r'''
      let
        flake = builtins.getFlake (toString ./.);
        repo = toString ./.;
        outPath = toString flake.outPath;
      in if builtins.substring 0 11 outPath == "/nix/store/" then outPath else repo
    '''
    return str(_run_json(repo, expr, timeout))


def _to_repo_relative(path: str | None, repo: Path, store_source: str) -> str | None:
    if not path:
        return None
    cleaned = path.split(", via option", 1)[0].rsplit(":", 1)[0]
    cleaned_path = Path(cleaned)
    try:
        rel = cleaned_path.resolve().relative_to(repo.resolve()).as_posix()
        return rel if rel != "." else "flake.nix"
    except Exception:
        pass

    # Flake evaluation copies the working tree into a content-addressed source
    # path. That path can differ between separate nix eval calls when the
    # working tree changes, so do not require exact store hash equality. Any
    # /nix/store/*-source path with the same relative file layout can be mapped
    # back to the repo if the relative path exists here.
    parts = cleaned_path.parts
    if len(parts) >= 4 and parts[1] == "nix" and parts[2] == "store" and parts[3].endswith("-source"):
        rel = Path(*parts[4:]).as_posix() if len(parts) > 4 else ""
        if rel and (repo / rel).exists():
            return rel
        if not rel and (repo / "flake.nix").exists():
            return "flake.nix"

    if cleaned == store_source:
        return "flake.nix" if (repo / "flake.nix").exists() else None
    prefix = store_source.rstrip("/") + "/"
    if cleaned.startswith(prefix):
        rel = cleaned[len(prefix):]
        return rel or None
    return None


def _add_edge(edges: list[dict[str, Any]], seen: set[tuple[str, str, str]], source: str, target: str | None, proof: str, reason: str, **extra: Any) -> None:
    if not target:
        return
    key = (source, target, proof)
    if key in seen:
        return
    seen.add(key)
    row = {
        "source": source,
        "target": target,
        "edge_type": "nix_reachability",
        "proof_type": proof,
        "confidence": "high",
        "reason": reason,
    }
    row.update(extra)
    edges.append(row)


def _collect_output_positions(repo: Path, store_source: str, timeout: int, edges: list[dict[str, Any]], seen: set[tuple[str, str, str]]) -> None:
    expr = r'''
      let
        flake = builtins.getFlake (toString ./.);
        systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
        has = set: name: builtins.isAttrs set && builtins.hasAttr name set;
        posOrNull = name: set:
          let pos = builtins.unsafeGetAttrPos name set;
          in if pos == null then null else { file = pos.file; line = pos.line; column = pos.column; };
        metaPosition = value: value.meta.position or null;
        collectSystem = attrName:
          if !(has flake.outputs attrName) then [] else
          builtins.concatLists (map (system:
            if !(has flake.outputs.${attrName} system) then [] else
            builtins.map (name: {
              output = "${attrName}.${system}.${name}";
              position = posOrNull name flake.outputs.${attrName}.${system};
              metaPosition = metaPosition flake.outputs.${attrName}.${system}.${name};
              proof = "nix_eval_output_position";
            }) (builtins.attrNames flake.outputs.${attrName}.${system})
          ) systems);
        collectSystemSingleton = attrName:
          if !(has flake.outputs attrName) then [] else
          builtins.concatLists (map (system:
            if !(has flake.outputs.${attrName} system) then [] else [{
              output = "${attrName}.${system}";
              position = posOrNull system flake.outputs.${attrName};
              metaPosition = metaPosition flake.outputs.${attrName}.${system};
              proof = "nix_eval_output_position";
            }]
          ) systems);
        collectTopLevel = attrName:
          if !(has flake.outputs attrName) then [] else
          let value = flake.outputs.${attrName}; in
          if builtins.isAttrs value then
            builtins.map (name: {
              output = "${attrName}.${name}";
              position = posOrNull name value;
              metaPosition = null;
              proof = "nix_eval_output_position";
            }) (builtins.attrNames value)
          else [{
            output = attrName;
            position = posOrNull attrName flake.outputs;
            metaPosition = null;
            proof = "nix_eval_output_position";
          }];
        conventional =
          (collectSystem "packages")
          ++ (collectSystem "checks")
          ++ (collectSystem "devShells")
          ++ (collectSystem "apps")
          ++ (collectSystemSingleton "formatter")
          ++ (collectSystemSingleton "legacyPackages")
          ++ (collectTopLevel "nixosConfigurations")
          ++ (collectTopLevel "homeConfigurations")
          ++ (collectTopLevel "darwinConfigurations")
          ++ (collectTopLevel "nixosModules")
          ++ (collectTopLevel "homeManagerModules")
          ++ (collectTopLevel "darwinModules")
          ++ (collectTopLevel "templates")
          ++ (collectTopLevel "overlays")
          ++ (collectTopLevel "lib");
        conventionalNames = [
          "packages" "checks" "devShells" "apps" "formatter" "legacyPackages"
          "nixosConfigurations" "homeConfigurations" "darwinConfigurations"
          "nixosModules" "homeManagerModules" "darwinModules" "templates" "overlays" "lib"
        ];
        customTopLevel =
          builtins.concatLists (map (name:
            if builtins.elem name conventionalNames then [] else [{
              output = name;
              position = posOrNull name flake.outputs;
              metaPosition = null;
              proof = "nix_eval_custom_output_position";
            }]
          ) (builtins.attrNames flake.outputs));
        inputPaths = builtins.mapAttrs (name: input: input.outPath or null) flake.inputs;
      in { outputs = conventional ++ customTopLevel; inputs = inputPaths; }
    '''
    data = _run_json(repo, expr, timeout)
    repo_resolved = repo.resolve()
    for name, path in data.get("inputs", {}).items():
        if not path:
            continue
        rel = None
        try:
            rel = Path(path).resolve().relative_to(repo_resolved).as_posix()
        except Exception:
            marker = "/./"
            if marker in str(path):
                candidate = str(path).split(marker, 1)[1].lstrip("/")
                if candidate and (repo / candidate).exists():
                    rel = candidate
            if rel is None:
                rel = _to_repo_relative(str(path), repo, store_source)
        if rel is None:
            continue
        default_target = rel.rstrip("/") + "/flake.nix"
        target = default_target if (repo / default_target).exists() else rel
        _add_edge(
            edges,
            seen,
            f"flake.input.{name}",
            target,
            "nix_eval_flake_input",
            "local flake input outPath from evaluated flake inputs",
            input=name,
        )
    for item in data.get("outputs", []):
        pos = item.get("position") or {}
        rel = _to_repo_relative(pos.get("file"), repo, store_source)
        _add_edge(
            edges,
            seen,
            item["output"],
            rel,
            item.get("proof", "nix_eval_output_position"),
            "flake output attribute position from builtins.unsafeGetAttrPos",
            line=pos.get("line"),
            column=pos.get("column"),
        )
        meta_rel = _to_repo_relative(item.get("metaPosition"), repo, store_source)
        _add_edge(
            edges,
            seen,
            item["output"],
            meta_rel,
            "nix_eval_derivation_position",
            "derivation meta.position from evaluated flake output",
        )


def _collect_nixos_definitions(repo: Path, store_source: str, timeout: int, edges: list[dict[str, Any]], seen: set[tuple[str, str, str]], config: str) -> None:
    expr = f'''
      let
        flake = builtins.getFlake (toString ./.);
        cfg = flake.outputs.nixosConfigurations.{config};
        optionByPath = path:
          builtins.foldl'
            (value: name: if value == null || !(builtins.isAttrs value) || !(builtins.hasAttr name value) then null else builtins.getAttr name value)
            cfg.options
            (builtins.split "\\." path);
        optionNames = [
          "environment.systemPackages"
          "systemd.services"
          "boot.loader.systemd-boot.enable"
          "services.hermes-agent.settings"
          "services.hermes-agent.extraPackages"
          "services.hermes-agent.extraPythonPackages"
          "services.hermes-agent.extraPlugins"
          "virtualisation.docker.enable"
          "sops.secrets"
        ];
        optionSets = builtins.filter (x: x.opt != null) (map (name: {{ inherit name; opt = optionByPath name; }}) optionNames);
        defs = optName: opt: map (def: {{ option = optName; file = def.file; }}) (opt.definitionsWithLocations or []);
        modules = map (m: if builtins.isPath m then toString m else if builtins.isString m then m else null) cfg._module.args.modules;
      in {{ definitions = builtins.concatLists (map (x: defs x.name x.opt) optionSets); modules = modules; }}
    '''
    data = _run_json(repo, expr, timeout)
    for module in data.get("modules", []):
        rel = _to_repo_relative(module, repo, store_source)
        _add_edge(edges, seen, f"nixosConfigurations.{config}", rel, "nix_eval_module", "module path from evaluated NixOS configuration")
    for item in data.get("definitions", []):
        rel = _to_repo_relative(item.get("file"), repo, store_source)
        _add_edge(
            edges,
            seen,
            f"nixosConfigurations.{config}:{item.get('option')}",
            rel,
            "nix_eval_option_definition",
            "option definition location from evaluated NixOS configuration",
            option=item.get("option"),
        )


def _collect_static_nix_path_edges(repo: Path, edges: list[dict[str, Any]], seen: set[tuple[str, str, str]]) -> None:
    """Add conservative syntax-derived path edges for literal Nix paths."""
    path_pattern = re.compile(r'(?<![\w$])(?:path:)?\./[-+._/A-Za-z0-9]+|(?<![\w$])\.\./[-+._/A-Za-z0-9]+')
    repo_resolved = repo.resolve()
    for source_path in repo.rglob("*.nix"):
        source_parts = set(source_path.parts)
        if ".git" in source_parts or ".repowise" in source_parts:
            continue
        source_rel = source_path.relative_to(repo).as_posix()
        try:
            text = source_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for match in path_pattern.finditer(text):
            raw = match.group(0)
            raw_path = raw.removeprefix("path:")
            base = (source_path.parent / raw_path).resolve()
            try:
                base.relative_to(repo_resolved)
            except Exception:
                continue
            if base.suffix == ".nix":
                candidates = [base]
            else:
                candidates = [base.with_suffix(".nix"), base / "flake.nix", base / "default.nix"]
            for candidate in candidates:
                if candidate.exists():
                    _add_edge(
                        edges,
                        seen,
                        source_rel,
                        candidate.relative_to(repo_resolved).as_posix(),
                        "nix_static_literal_path",
                        "literal Nix path reference from source text",
                        literal=raw,
                    )
                    break


def main() -> int:
    parser = argparse.ArgumentParser(description="Collect Nix evaluator reachability evidence as JSON")
    parser.add_argument("repo", nargs="?", default=os.environ.get("REPOWISE_REPO", "."))
    parser.add_argument("--nixos-config", action="append", default=[])
    parser.add_argument("--timeout", type=int, default=120)
    args = parser.parse_args()

    repo = Path(args.repo).resolve()
    store_source = _store_source_mapping(repo, args.timeout)
    edges: list[dict[str, Any]] = []
    seen: set[tuple[str, str, str]] = set()

    _collect_output_positions(repo, store_source, args.timeout, edges, seen)
    for config in args.nixos_config:
        _collect_nixos_definitions(repo, store_source, args.timeout, edges, seen, config)
    _collect_static_nix_path_edges(repo, edges, seen)

    files = sorted({edge["target"] for edge in edges})
    print(json.dumps({"repo": str(repo), "store_source": store_source, "files": files, "edges": edges}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
