{
  lib,
  python313Packages,
  fetchFromGitHub,
}:

let
  py = python313Packages;
  grammars = py.tree-sitter-grammars;
in
py.buildPythonApplication {
  pname = "repowise";
  version = "0.10.0-repowise-nix";

  src = fetchFromGitHub {
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

  # The pinned nixpkgs does not currently package tree-sitter-swift or
  # tree-sitter-luau for Python 3.13. Repowise loads grammars lazily; the Nix
  # package's supported path needs Nix/Python/TS/etc., not Swift/Luau parsing.
  # Keep import checks below as the real runtime gate instead of failing the
  # whole package on unused optional grammars.
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
    pandas
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
}
