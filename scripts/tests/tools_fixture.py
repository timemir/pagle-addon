"""The pinned tools a test runs (scripts/setup.sh's .tools/), found where scripts/check.sh runs them from: $PAGLE_TOOLS,
this checkout's .tools/, or a linked worktree's main checkout's (scripts/lib/tools.sh's tools_dir, the one copy of that
rule). A test whose tool is missing skips, saying which and where, so a fresh worktree with no toolchain anywhere still
runs the rest; in CI, which always installs them, a missing tool fails the test instead of skipping it quietly."""

import os
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]


def tools_dir(root: Path = REPO) -> Path:
    """The .tools/ the checkout at root runs its tools from, as scripts/lib/tools.sh's tools_dir answers it."""
    done = subprocess.run(
        ["bash", "-c", 'source "$1/scripts/lib/tools.sh" && tools_dir "$1"', "tools_dir", str(root)],
        capture_output=True,
        text=True,
        check=True,
    )
    return Path(done.stdout.strip())


def tool(relative: str, tools: Path | None = None) -> Path:
    """The tool at `relative` in the tools' directory (`bin/lua`, `lua/bin/luac`). Missing, the test skips, or fails
    under CI (the CI variable GitHub Actions sets)."""
    path = (tools or tools_dir()) / relative
    if not path.exists():
        message = f"no {path}: run scripts/setup.sh in the main checkout"
        if os.environ.get("CI"):
            pytest.fail(f"{message}; CI installs every tool, so a missing one fails here")
        pytest.skip(message)
    return path
